/*
//
//  Examples.swift
//  americo-media-converter
//
//  Created by Americo Cot on 5/10/25.
//

// MARK: - Usage Examples

// Example 1: Run a simple command
func example1() {
    do {
        let result = try CommandRunner.run(
            command: "/bin/ls",
            arguments: ["-la", "/tmp"]
        )
        
        print("Exit Code: \(result.exitCode)")
        print("Output:\n\(result.stdout)")
        
        if !result.stderr.isEmpty {
            print("Errors:\n\(result.stderr)")
        }
    } catch {
        print("Error: \(error)")
    }
}

// Example 2: Run a shell command
func example2() {
    do {
        let result = try CommandRunner.runShell("echo 'Hello, World!' | wc -w")
        print("Word count: \(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
    } catch {
        print("Error: \(error)")
    }
}

// Example 3: Run with custom working directory
func example3() {
    do {
        let result = try CommandRunner.run(
            command: "/usr/bin/find",
            arguments: [".", "-name", "*.swift", "-type", "f"],
            workingDirectory: "/Users/youruser/Projects"
        )
        print("Swift files found:\n\(result.stdout)")
    } catch {
        print("Error: \(error)")
    }
}

// Example 4: Async execution with streaming output
func example4() {
    CommandRunner.runAsync(
        command: "/usr/bin/ping",
        arguments: ["-c", "5", "google.com"],
        onOutput: { output in
            print("📤 \(output)", terminator: "")
        },
        onError: { error in
            print("⚠️ \(error)", terminator: "")
        },
        completion: { exitCode in
            print("\n✅ Process completed with exit code: \(exitCode)")
        }
    )
}

// Example 5: Check command success
func example5() {
    do {
        let result = try CommandRunner.run(
            command: "/usr/bin/which",
            arguments: ["swift"]
        )
        
        if result.isSuccess {
            print("Swift found at: \(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        } else {
            print("Swift not found")
        }
    } catch {
        print("Error: \(error)")
    }
}
*/
