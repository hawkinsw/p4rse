// The Swift Programming Language
// https://docs.swift.org/swift-book

import P4
import SwiftTreeSitter
import TreeSitterP4

extension MutableTree {
    public func isError(lang: Language) -> Bool {
        // TODO: Make a function.
        guard
            let parser_error_query = try? SwiftTreeSitter.Query(
                language: lang,
                data: String(
                    "(ERROR)"
                ).data(using: String.Encoding.utf8)!)
        else {
            return false
        }

        let error_qr = parser_error_query.execute(in: self)
        for _ in error_qr {
            return true
        }

        return false
    }
}

let p4lang = Language(tree_sitter_p4())

public protocol ParseableParserStatement {
    static func Parse(node: Node, inTree tree: MutableTree) -> P4.ParserStatement?
}

extension P4.ExpressionStatement : ParseableParserStatement{
    public static func Parse(node: Node, inTree tree: MutableTree) -> P4.ParserStatement? {
        return P4.ExpressionStatement()
    }
}

public struct Parser {
    static func ParserStatements(capture: [QueryCapture], inTree tree: MutableTree) -> [P4.ParserStatement]? {
        var statements: [P4.ParserStatement] = Array()

        let statementParsers = [P4.ExpressionStatement.self]

        for raw_statement in capture {
                var parsed_statement: Optional<P4.ParserStatement> = .none

                // Iterate through statement parsers and give each one a chance.
                for parser in statementParsers {
                    if let parsed = parser.Parse(node: raw_statement.node, inTree: tree) {
                        parsed_statement = parsed
                    }
                }

                if let statement = parsed_statement {
                    statements.append(statement)
                }  else {
                    // There were no parseable statements.
                    return nil
                }
        }

        return statements
    }

    static func ParserTransitionStatement(node: Node, inTree tree: MutableTree) -> P4
        .ParserTransitionStatement?
    {
        return P4.ParserTransitionStatement()
    }

    static func ParserState(node: Node, inTree tree: MutableTree) -> P4.ParserState? {
        guard
            let parser_state_query = try? SwiftTreeSitter.Query(
                language: p4lang,
                data: String(
                    "(parserState (state) (identifier) @state-name (parserStatements)? @state-statements (parserTransitionStatement) @transition)"
                ).data(using: String.Encoding.utf8)!)
        else {
            return nil
        }

        let qr = parser_state_query.execute(node: node, in: tree)

        // TODO: Assert that there is only one value here.
        for parser_declaration in qr {


            let transition_capture = parser_declaration.captures(
                named: "transition")
            let state_name_capture = parser_declaration.captures(named: "state-name")
            let statements_capture = parser_declaration.captures(named: "state-statements")

            guard !state_name_capture.isEmpty,
                !transition_capture.isEmpty,
                let parsed_state_name = state_name_capture[0].node.text,
                let transition_statement = ParserTransitionStatement(
                    node: transition_capture[0].node, inTree: tree)
            else {
                return nil
            }

            let parsed_statements = if !statements_capture.isEmpty {
                ParserStatements(capture: statements_capture, inTree: tree)
            } else {
                Optional<[P4.ParserStatement]>.none
            }

            // TODO: Validate that there is only one!
            return P4.ParserState(name: parsed_state_name, withStatements: parsed_statements, withTransition: transition_statement)
        }

        return nil
    }

    static func Parser(node: Node, inTree tree: MutableTree) -> P4.Parser? {
        guard
            let parser_state_query = try? SwiftTreeSitter.Query(
                language: p4lang,
                data: String(
                    "(parserStates) @parser-states"
                ).data(using: String.Encoding.utf8)!)
        else {
            return nil
        }

        var parser = P4.Parser()


        // Build a state from each one listed.
        for parser_states in parser_state_query.execute(node: node, in: tree) {
            if let state = ParserState(node: parser_states.nodes[0], inTree: tree) {
                parser.states.append(state)
            }
        }

        return parser
    }

    public static func Program(_ source: String) -> P4.Program? {

        let p = SwiftTreeSitter.Parser.init()

        do {
            try p.setLanguage(p4lang)
        } catch {
            return nil
        }

        // Parse and check whether it is valid.
        let result = p.parse(source)
        guard let tree = result,
            !tree.isError(lang: p4lang)
        else {

            return nil
        }

        // Query for the parser declarations.
        guard
            let parser_declaration_query = try? SwiftTreeSitter.Query(
                language: p4lang,
                data: String(
                    "(parserDeclaration (parserType) (parserStates) @parser-states)"
                ).data(using: String.Encoding.utf8)!)
        else {
            return nil
        }

        var program: P4.Program = P4.Program()

        let parser_qc = parser_declaration_query.execute(in: tree)

        for parser_declaration in parser_qc {
            if let parser = Parser(
                node: parser_declaration.nodes[0], inTree: tree)
            {
                program.parsers.append(parser)
            }
        }

        return program
    }
}
