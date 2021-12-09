import Foundation
import TuistLoader
import TuistPlugin
import TuistSupport
import TuistCore
import TSCBasic

enum TuistServiceError: FatalError {
    case taskUnavailable

    var type: ErrorType {
        switch self {
        case .taskUnavailable:
            return .abortSilent
        }
    }

    var description: String {
        switch self {
        case .taskUnavailable:
            return "Task was not found in the environment"
        }
    }
}

final class TuistService: NSObject {
    private let pluginService: PluginServicing
    private let configLoader: ConfigLoading

    init(
        pluginService: PluginServicing = PluginService(),
        configLoader: ConfigLoading = ConfigLoader(manifestLoader: CachedManifestLoader())
    ) {
        self.pluginService = pluginService
        self.configLoader = configLoader
    }

    func run(
        arguments: [String],
        tuistBinaryPath: String
    ) throws {
        var arguments = arguments

        let commandName = "tuist-\(arguments[0])"
        
        let path: AbsolutePath
        if let pathOptionIndex = arguments.firstIndex(of: "--path") ?? arguments.firstIndex(of: "--p") {
            path = AbsolutePath(
                arguments[pathOptionIndex + 1],
                relativeTo: FileHandler.shared.currentPath
            )
        } else {
            path = FileHandler.shared.currentPath
        }

        let config = try configLoader.loadConfig(path: path)
        let pluginExecutables = try pluginService.remotePluginPaths(using: config)
            .compactMap(\.releasePath)
            .flatMap(FileHandler.shared.contentsOfDirectory)
            .filter { $0.basename.hasPrefix("tuist-") }
        if let pluginCommand = pluginExecutables.first(where: { $0.basename == commandName }) {
            arguments[0] = pluginCommand.pathString
        } else if System.shared.commandExists(commandName) {
            arguments[0] = commandName
        } else {
            throw TuistServiceError.taskUnavailable
        }
        

        try System.shared.runAndPrint(
            arguments,
            verbose: Environment.shared.isVerbose,
            environment: [Constants.EnvironmentVariables.tuistBinaryPath: tuistBinaryPath]
        )
    }
}
