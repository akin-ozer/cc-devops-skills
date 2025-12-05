/**
 * buildApp - Build and test an application
 *
 * @param config Map containing build configuration:
 *   - language: Programming language (java, node, python)
 *   - testCommand: Command to run tests (optional)
 *   - buildCommand: Command to build (optional)
 * @return Map with build results
 *
 * Example usage:
 *   buildApp(language: 'java')
 *   buildApp(language: 'node', testCommand: 'npm test')
 */

def call(Map config = [:]) {
    def language = config.language ?: 'java'
    def testCommand = config.testCommand
    def buildCommand = config.buildCommand
    def results = [:]

    try {
        stage('Build') {
            echo "Building ${language} application..."

            switch (language) {
                case 'java':
                    sh '''
                        ./mvnw clean package -DskipTests
                        echo "Build complete"
                    '''
                    break
                case 'node':
                    sh '''
                        npm ci
                        npm run build
                    '''
                    break
                case 'python':
                    sh '''
                        pip install -r requirements.txt
                        python setup.py build
                    '''
                    break
                default:
                    if (buildCommand) {
                        sh buildCommand
                    } else {
                        error "Unknown language: ${language}"
                    }
            }
            results.buildStatus = 'SUCCESS'
        }

        stage('Test') {
            echo "Running tests..."
            try {
                if (testCommand) {
                    sh testCommand
                } else {
                    switch (language) {
                        case 'java':
                            sh './mvnw test'
                            break
                        case 'node':
                            sh 'npm test'
                            break
                        case 'python':
                            sh 'pytest tests/'
                            break
                    }
                }
                results.testStatus = 'SUCCESS'
            } catch (Exception e) {
                results.testStatus = 'FAILED'
                results.testError = e.message
                throw e
            } finally {
                // Publish test results
                junit allowEmptyResults: true, testResults: '**/test-results/*.xml'
            }
        }

        return results

    } catch (Exception e) {
        results.error = e.message
        throw e
    }
}

/**
 * Helper method to get version from pom.xml
 * Must be @NonCPS because it uses Groovy XML parsing
 */
@NonCPS
def getVersionFromPom(String pomFile = 'pom.xml') {
    def pom = new XmlSlurper().parse(pomFile)
    return pom.version.text()
}

/**
 * Helper method to parse JSON configuration
 * @NonCPS required for JsonSlurperClassic
 */
@NonCPS
def parseConfig(String jsonText) {
    def slurper = new groovy.json.JsonSlurperClassic()
    return slurper.parseText(jsonText)
}