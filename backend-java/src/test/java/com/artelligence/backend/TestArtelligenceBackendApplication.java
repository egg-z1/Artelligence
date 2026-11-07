package com.artelligence.backend;

import org.springframework.boot.SpringApplication;

public class TestArtelligenceBackendApplication {

	public static void main(String[] args) {
		SpringApplication.from(ArtelligenceBackendApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
