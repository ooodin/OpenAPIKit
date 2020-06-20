//
//  DereferencedOperation.swift
//  
//
//  Created by Mathew Polzin on 6/18/20.
//

/// An `OpenAPI.Operation` type that guarantees
/// its `parameters`, `requestBody`, `responses`,
/// and `security` are inlined instead of referenced.
@dynamicMemberLookup
public struct DereferencedOperation: Equatable {
    public let underlyingOperation: OpenAPI.Operation
    public let parameters: [DereferencedParameter]
    public let requestBody: DereferencedRequest?
    public let responses: OrderedDictionary<OpenAPI.Response.StatusCode, DereferencedResponse>
    public let security: [DereferencedSecurityRequirement]?

    public subscript<T>(dynamicMember path: KeyPath<OpenAPI.Operation, T>) -> T {
        return underlyingOperation[keyPath: path]
    }

    /// Create a `DereferencedOperation` if all references in the
    /// operation can be found in the given Components Object.
    ///
    /// - Throws: `ReferenceError.cannotLookupRemoteReference` or
    ///     `MissingReferenceError.referenceMissingOnLookup(name:)` depending
    ///     on whether an unresolvable reference points to another file or just points to a
    ///     component in the same file that cannot be found in the Components Object.
    public init(operation: OpenAPI.Operation, resolvingIn components: OpenAPI.Components) throws {
        self.parameters = try operation.parameters.map { parameter in
            try DereferencedParameter(
                parameter: try components.forceDereference(parameter),
                resolvingIn: components
            )
        }

        self.requestBody = try operation.requestBody.map { request in
            try DereferencedRequest(
                request: try components.forceDereference(request),
                resolvingIn: components
            )
        }

        self.responses = try operation.responses.mapValues { response in
            try DereferencedResponse(
                response: try components.forceDereference(response),
                resolvingIn: components
            )
        }

        self.security = try operation.security?.map { try DereferencedSecurityRequirement(securityRequirement: $0, resolvingIn: components) }

        self.underlyingOperation = operation
    }
}

extension DereferencedOperation {
    /// A `ResponseOutcome` is the combination of a
    /// status code and a response.
    public struct ResponseOutcome: Equatable {
        public let status: OpenAPI.Response.StatusCode
        public let response: DereferencedResponse

        public init(
            status: OpenAPI.Response.StatusCode,
            response: DereferencedResponse
        ) {
            self.status = status
            self.response = response
        }
    }

    /// Get all response outcomes for this operation.
    ///
    /// - Returns: An array of `ResponseOutcomes` with the status
    ///     and the response for the status.
    public var responseOutcomes: [ResponseOutcome] {
        return responses.map { (status, response) in .init(status: status, response: response) }
    }
}
