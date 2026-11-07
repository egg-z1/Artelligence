package com.artelligence.backend;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.OffsetDateTime;
import java.util.UUID;

import javax.sql.DataSource;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@SpringBootTest
class DatabaseSchemaIntegrationTest {
    static final PostgreSQLContainer postgres = new PostgreSQLContainer(DockerImageName.parse("postgres:17.11"));

    static { postgres.start(); }

    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired JdbcTemplate jdbc;
    @Autowired DataSource dataSource;

    @Test
    void flywayAppliedAndDatabaseConnects() throws Exception {
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM flyway_schema_history WHERE success", Integer.class));
        assertEquals(7, jdbc.queryForObject("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' AND table_name <> 'flyway_schema_history'", Integer.class));
        try (Connection connection = dataSource.getConnection()) {
            assertEquals(true, connection.isValid(2));
        }
    }

    @Test
    void acceptsValidRowsAndRejectsUniqueForeignKeyAndCheckViolations() {
        UUID member = UUID.randomUUID();
        UUID work = UUID.randomUUID();
        UUID job = UUID.randomUUID();
        OffsetDateTime now = OffsetDateTime.now();
        jdbc.update("INSERT INTO members(id,nickname,created_at,updated_at) VALUES (?,?,?,?)", member, "tester", now, now);
        jdbc.update("INSERT INTO credit_accounts(member_id,updated_at) VALUES (?,?)", member, now);
        jdbc.update("INSERT INTO works(id,owner_id,title,created_at,updated_at) VALUES (?,?,?,?,?)", work, member, "미분류", now, now);
        jdbc.update("INSERT INTO works(id,owner_id,title,is_uncategorized,created_at,updated_at) VALUES (?,?,?,?,?,?)", UUID.randomUUID(), member, "다른 미분류 제목", true, now, now);
        jdbc.update("INSERT INTO social_accounts(id,member_id,provider,provider_user_id,created_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), member, "google", "subject", now);
        assertSqlState("23505", () -> jdbc.update("INSERT INTO social_accounts(id,member_id,provider,provider_user_id,created_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), member, "google", "subject", now));

        jdbc.update("INSERT INTO generation_jobs(id,member_id,work_id,idempotency_key,request_hash,prompt,size,quality,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)", job, member, work, "key-1", "a".repeat(64), "prompt", "1024x1024", "standard", now, now);
        assertSqlState("23505", () -> jdbc.update("INSERT INTO generation_jobs(id,member_id,work_id,idempotency_key,request_hash,prompt,size,quality,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)", UUID.randomUUID(), member, work, "key-1", "b".repeat(64), "prompt", "1024x1024", "standard", now, now));
        assertSqlState("23503", () -> jdbc.update("INSERT INTO works(id,owner_id,title,created_at,updated_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), UUID.randomUUID(), "bad", now, now));
        assertSqlState("23503", () -> jdbc.update("INSERT INTO generation_jobs(id,member_id,work_id,idempotency_key,request_hash,prompt,size,quality,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)", UUID.randomUUID(), member, UUID.randomUUID(), "key-2", "c".repeat(64), "prompt", "1024x1024", "standard", now, now));
        assertSqlState("23514", () -> jdbc.update("INSERT INTO credit_accounts(member_id,available,reserved,version,updated_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), -1, 0, 0, now));
        assertSqlState("23514", () -> jdbc.update("INSERT INTO images(id,work_id,blob_name,prompt,content_type,byte_size,created_at) VALUES (?,?,?,?,?,?,?)", UUID.randomUUID(), work, "neg", "p", "image/png", -1, now));
        assertSqlState("23514", () -> jdbc.update("INSERT INTO members(id,nickname,role,created_at,updated_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), "bad", "ROOT", now, now));
    }

    private static void assertSqlState(String expected, Runnable action) {
        RuntimeException exception = assertThrows(RuntimeException.class, action::run);
        Throwable cause = exception;
        while (cause != null && !(cause instanceof SQLException)) cause = cause.getCause();
        if (cause instanceof SQLException sqlException) assertEquals(expected, sqlException.getSQLState());
        else throw new AssertionError("Expected SQLState " + expected, exception);
    }
}
