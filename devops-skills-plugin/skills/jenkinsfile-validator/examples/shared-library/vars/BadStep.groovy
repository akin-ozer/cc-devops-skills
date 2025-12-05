// BAD SHARED LIBRARY EXAMPLE - Contains multiple validation issues
// This file is intentionally written poorly to demonstrate validation capabilities

// Missing documentation comment - WARNING

// Bad filename: should be camelCase starting with lowercase (badStep.groovy) - WARNING

// Missing call() method - WARNING

def execute(String command) {
    // Hardcoded credentials - ERROR
    def password = "supersecret123"
    def apiKey = "sk-1234567890abcdef"

    // Using System.getenv instead of env - WARNING
    def home = System.getenv("HOME")

    // Using Thread.sleep instead of sleep() step - WARNING
    Thread.sleep(5000)

    // Using new File() instead of readFile - WARNING
    def config = new File('config.json').text

    // HTTP request on controller - WARNING
    def url = new URL("http://api.example.com/data")
    def response = url.text

    // JsonSlurper on controller without @NonCPS - WARNING
    def slurper = new groovy.json.JsonSlurper()
    def data = slurper.parseText(response)

    // Using closures without @NonCPS - INFO
    data.items.each { item ->
        echo "Processing: ${item.name}"
    }

    sh command
}

// @NonCPS method with pipeline steps - ERROR
@NonCPS
def processWithSteps() {
    sh 'echo "This will fail!"'  // Cannot use pipeline steps in @NonCPS
    echo "This too!"
    sleep 5  // Async steps not allowed in @NonCPS
}

// Method with closure that should be @NonCPS
def transformData(List items) {
    // .collect{} requires @NonCPS - INFO
    return items.collect { it.toUpperCase() }
}