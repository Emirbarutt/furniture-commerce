plugins {
  java
  id("org.springframework.boot") version "3.5.14"
  id("io.spring.dependency-management") version "1.1.7"
}

group = "com.furniturecommerce"
version = "0.1.0-SNAPSHOT"

java {
  toolchain {
    languageVersion = JavaLanguageVersion.of(21)
  }
}

repositories {
  mavenCentral()
}

dependencies {
  implementation("org.springframework.boot:spring-boot-starter-web")
  implementation("org.springframework.boot:spring-boot-starter-security")
  implementation("org.springframework.boot:spring-boot-starter-data-jpa")
  implementation("org.springframework.boot:spring-boot-starter-validation")
  implementation("org.springframework.boot:spring-boot-starter-actuator")
  implementation("org.flywaydb:flyway-core")
  implementation("org.flywaydb:flyway-database-postgresql")
  implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.17")
  implementation("org.mapstruct:mapstruct:1.6.3")

  runtimeOnly("org.postgresql:postgresql")

  compileOnly("org.projectlombok:lombok")
  annotationProcessor("org.projectlombok:lombok")
  annotationProcessor("org.mapstruct:mapstruct-processor:1.6.3")

  testImplementation("org.springframework.boot:spring-boot-starter-test")
  testImplementation("org.testcontainers:junit-jupiter")
  testImplementation("org.testcontainers:postgresql")
}

tasks.withType<Test> {
  useJUnitPlatform()
}
