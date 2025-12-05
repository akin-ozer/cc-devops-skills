package com.example

import groovy.transform.ToString

/**
 * BuildConfig - Configuration class for build parameters
 * Implements Serializable for CPS compatibility
 */
@ToString
class BuildConfig implements Serializable {
    private static final long serialVersionUID = 1L

    String language
    String buildCommand
    String testCommand
    boolean skipTests = false
    Map<String, String> environment = [:]

    BuildConfig() {}

    BuildConfig(Map config) {
        this.language = config.language ?: 'java'
        this.buildCommand = config.buildCommand
        this.testCommand = config.testCommand
        this.skipTests = config.skipTests ?: false
        this.environment = config.environment ?: [:]
    }

    /**
     * Validate configuration
     */
    void validate() {
        if (!language) {
            throw new IllegalArgumentException("Language is required")
        }
    }

    /**
     * Get default build command for language
     */
    String getDefaultBuildCommand() {
        switch (language) {
            case 'java': return './mvnw clean package'
            case 'node': return 'npm run build'
            case 'python': return 'python setup.py build'
            default: return buildCommand
        }
    }
}