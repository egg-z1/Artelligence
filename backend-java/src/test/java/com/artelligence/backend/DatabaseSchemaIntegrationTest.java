package com.artelligence.backend;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.sql.Connection;
import java.sql.SQLException;
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
import org.postgresql.util.PSQLException;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@SpringBootTest
@ActiveProfiles("test")
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
        jdbc.update("INSERT INTO works(id,owner_id,title,is_uncategorized,created_at,updated_at) VALUES (?,?,?,?,?,?)", work, member, "미분류", true, now, now);
        assertViolation("23505", "uq_works_one_uncategorized_per_owner", () -> jdbc.update("INSERT INTO works(id,owner_id,title,is_uncategorized,created_at,updated_at) VALUES (?,?,?,?,?,?)", UUID.randomUUID(), member, "분류 안 됨", true, now, now));
        UUID otherMember = UUID.randomUUID();
        jdbc.update("INSERT INTO members(id,nickname,created_at,updated_at) VALUES (?,?,?,?)", otherMember, "another", now, now);
        jdbc.update("INSERT INTO works(id,owner_id,title,is_uncategorized,created_at,updated_at) VALUES (?,?,?,?,?,?)", UUID.randomUUID(), otherMember, "미분류", true, now, now);
        jdbc.update("INSERT INTO works(id,owner_id,title,created_at,updated_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), member, "같은 제목", now, now);
        jdbc.update("INSERT INTO works(id,owner_id,title,created_at,updated_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), member, "같은 제목", now, now);
        jdbc.update("INSERT INTO social_accounts(id,member_id,provider,provider_user_id,created_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), member, "google", "subject", now);
        assertViolation("23505", "uq_social_accounts_provider_user", () -> jdbc.update("INSERT INTO social_accounts(id,member_id,provider,provider_user_id,created_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), member, "google", "subject", now));

        jdbc.update("INSERT INTO generation_jobs(id,member_id,work_id,idempotency_key,request_hash,prompt,size,quality,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)", job, member, work, "key-1", "a".repeat(64), "prompt", "1024x1024", "standard", now, now);
        assertViolation("23505", "uq_jobs_member_idempotency", () -> jdbc.update("INSERT INTO generation_jobs(id,member_id,work_id,idempotency_key,request_hash,prompt,size,quality,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)", UUID.randomUUID(), member, work, "key-1", "b".repeat(64), "prompt", "1024x1024", "standard", now, now));
        assertViolation("23503", "works_owner_id_fkey", () -> jdbc.update("INSERT INTO works(id,owner_id,title,created_at,updated_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), UUID.randomUUID(), "bad", now, now));
        assertViolation("23503", "generation_jobs_work_id_fkey", () -> jdbc.update("INSERT INTO generation_jobs(id,member_id,work_id,idempotency_key,request_hash,prompt,size,quality,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)", UUID.randomUUID(), member, UUID.randomUUID(), "key-2", "c".repeat(64), "prompt", "1024x1024", "standard", now, now));

        UUID imageJob = UUID.randomUUID();
        jdbc.update("INSERT INTO generation_jobs(id,member_id,work_id,idempotency_key,request_hash,prompt,size,quality,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)", imageJob, member, work, "key-image", "d".repeat(64), "prompt", "1024x1024", "standard", now, now);
        jdbc.update("INSERT INTO images(id,work_id,generation_job_id,blob_name,prompt,content_type,byte_size,created_at) VALUES (?,?,?,?,?,?,?,?)", UUID.randomUUID(), work, imageJob, "generated/one.png", "p", "image/png", 10, now);
        assertViolation("23505", "images_generation_job_id_key", () -> jdbc.update("INSERT INTO images(id,work_id,generation_job_id,blob_name,prompt,content_type,byte_size,created_at) VALUES (?,?,?,?,?,?,?,?)", UUID.randomUUID(), work, imageJob, "generated/two.png", "p", "image/png", 10, now));
        jdbc.update("INSERT INTO images(id,work_id,generation_job_id,blob_name,prompt,content_type,byte_size,created_at) VALUES (?,?,?,?,?,?,?,?)", UUID.randomUUID(), work, null, "legacy/one.png", "p", "image/png", 10, now);
        jdbc.update("INSERT INTO images(id,work_id,generation_job_id,blob_name,prompt,content_type,byte_size,created_at) VALUES (?,?,?,?,?,?,?,?)", UUID.randomUUID(), work, null, "legacy/two.png", "p", "image/png", 10, now);

        assertViolation("23514", "credit_accounts_available_check", () -> jdbc.update("INSERT INTO credit_accounts(member_id,available,reserved,version,updated_at) VALUES (?,?,?,?,?)", member, -1, 0, 0, now));
        assertViolation("23514", "ck_credit_entries_delta", () -> insertCredit(member, job, "RESERVE", 0, 1, "bad-delta", now));
        assertViolation("23514", "ck_credit_entries_job", () -> insertCredit(member, null, "COMMIT", 0, -1, "missing-job-commit", now));
        assertViolation("23514", "ck_credit_entries_job", () -> insertCredit(member, null, "RESERVE", -1, 1, "missing-job-reserve", now));
        assertViolation("23514", "ck_credit_entries_job", () -> insertCredit(member, null, "RELEASE", 1, -1, "missing-job-release", now));
        insertCredit(member, job, "RESERVE", -1, 1, "op-duplicate", now);
        assertViolation("23505", "uq_credit_entries_member_operation", () -> insertCredit(member, job, "RESERVE", -1, 1, "op-duplicate", now));
        assertViolation("23514", "members_role_check", () -> jdbc.update("INSERT INTO members(id,nickname,role,created_at,updated_at) VALUES (?,?,?,?,?)", UUID.randomUUID(), "bad", "ROOT", now, now));
    }

    private void insertCredit(UUID member, UUID job, String event, int availableDelta, int reservedDelta, String operationKey, OffsetDateTime now) {
        jdbc.update("INSERT INTO credit_entries(id,member_id,generation_job_id,event_type,available_delta,reserved_delta,operation_key,created_at) VALUES (?,?,?,?,?,?,?,?)", UUID.randomUUID(), member, job, event, availableDelta, reservedDelta, operationKey, now);
    }

    private static void assertViolation(String expectedState, String expectedConstraint, Runnable action) {
        RuntimeException exception = assertThrows(RuntimeException.class, action::run);
        Throwable cause = exception;
        while (cause != null && !(cause instanceof SQLException)) cause = cause.getCause();
        if (cause instanceof PSQLException sqlException) {
            assertEquals(expectedState, sqlException.getSQLState());
            assertEquals(expectedConstraint, sqlException.getServerErrorMessage().getConstraint());
        } else throw new AssertionError("Expected SQLState " + expectedState, exception);
    }
}
