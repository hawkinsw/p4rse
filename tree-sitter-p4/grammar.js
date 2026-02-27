// p4rse, Copyright 2026, Will Hawkins
//
// This file is part of p4rse.

// This file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

export default grammar({
    name: 'p4',
    rules: {
        // Start symbol
        p4program: $ => optional(repeat(seq(choice($.declaration, $.instantiation), $._semicolon))),

        // Common

        // Common - Parameters
        typeParameters: $ => seq('<', $.typeParameterList, '>'),
        typeParameterList: $ => choice("[a-z]+", seq($.typeParameterList, ',', "[a-z]+")),
        parameterList: $ => choice($.parameter, seq($.parameterList, ',', $.parameter)),
        parameter: $ => choice(seq(optional($.annotations), optional($.direction), $.typeRef, $.identifier), seq(optional($.annotations), optional($.direction), $.typeRef, $.identifier, '=', $.expression)),
        direction: $ => choice($.in, $.out, $.inout),

        // Common - Types
        typeRef: $ => $.baseType,
        baseType: $ => choice($.bool, $.error, $.string, $.int, $.bit /* omitting "templated" types" */),
        constructorParameters: $ => seq('(', optional($.parameterList), ')'),

        // Common - Parsers
        parserType: $ => seq(optional($.annotations), $.parser, field('parser_name', $.identifier), optional($.typeParameters), '(', optional($.parameterList), ')'),

        // Mark with higher precedence so that the local states are preferred when parsing!
        // TODO: Test!
        parserLocalElements: $ => prec(2, repeat1($.parserLocalElement)),

        parserStates: $ => repeat1($.parserState),
        parserState: $ => seq(optional($.annotations), $.state, $.identifier, '{', optional($.parserLocalElements), optional($.parserStatements), $.parserTransitionStatement, '}'),

        parserLocalElement: $ => choice($.variableDeclaration, $.todo),

        selectBody: $ => repeat1(seq($.selectCase, $._semicolon)),
        selectCase: $ => seq($.keysetExpression, $.colon, $.identifier),

        annotations: $ => repeat1($.annotation),

        //annotation: $ => choice(seq('@', "[a-z]+"), seq('@', "[a-z]+", '(', $.annotationBody, ')'), seq('@', "[a-z]+", '[', $.structuredAnnotationBody, ']')),
        annotation: $ => choice(seq('@', "[a-z]+")),// seq('@', "[a-z]+", '(', /* empty for now*/ ')'), seq('@', "[a-z]+", '[', /* empty for now */ ']')),


        // Instantiation
        instantiation: $ => seq($.typeRef, '(', optional($.parameterList), ')', $.identifier),

        // Declarations
        declaration: $ => seq(choice($.parserDeclaration, $.parserTypeDeclaration)),

        // Make separate productions for the parser type and the parser type declaration because the latter can have type parameters.
        parserTypeDeclaration: $ => seq(optional($.annotations), $.parser, field('parser_name', $.identifier), optional($.typeParameters), '(', optional($.parameterList), ')'),
        parserDeclaration: $ => seq($.parserType, optional($.constructorParameters), '{', optional($.parserLocalElements), $.parserStates, '}'),

        variableDeclaration: $ => seq(optional($.annotations), $.typeRef, field('variable_name', $.identifier), optional(seq($.assignment, $.expression)), $._semicolon),

        // Statements

        // General statements
        statements: $ => repeat1($.statement),
        statement: $ => choice($.conditionalStatement, $.blockStatement, $.expressionStatement, $.assignmentStatement),// Limited, so far.
        blockStatement: $ => seq(optional($.annotations), '{', optional($.statements), '}'),
        conditionalStatement: $ => choice(prec(1, seq($.if, '(', $.expression, ')', $.statement)), prec(2, seq($.if, '(', $.expression, ')', $.statement, $.else, $.statement))),
        expressionStatement: $=> seq($.expression, $._semicolon),
        assignmentStatement: $=> seq($.expression, $.assignment, $.expression, $._semicolon),

        // Parser statements
        parserStatements: $ => repeat1($.parserStatement),
        parserStatement: $ => choice($.conditionalStatement, $.parserBlockStatement, $.expressionStatement, $.assignmentStatement), // Limited, so far.
        parserBlockStatement: $ => seq(optional($.annotations), '{', $.parserStatements, '}'),
        parserTransitionStatement: $ => seq($.transition, $.transitionSelectionExpression, $._semicolon),

        // Expressions
        expression: $ => choice($.identifier, $.integer, $.true, $.false, $.string_literal), // Very limited.
        selectExpression: $ => seq($.select, '(', $.expression, ')', '{', $.selectBody, '}'), // TODO: Should be expression list and not just a single expression
        transitionSelectionExpression: $ => choice($.identifier, $.selectExpression),
        keysetExpression: $ => $.expression,

        // Tokens
        _semicolon: $ => ";",
        colon: $ => ":",
        assignment: $ => "=",
        todo: $ => "todo",
        abstract: $ => "abstract",
        action: $ => "action",
        actions: $ => "actions",
        apply: $ => "apply",
        bool: $ => "bool",
        bit: $ => "bit",
        const: $ => "const",
        control: $ => "control",
        default: $ => "default",
        else: $ => "else",
        entries: $ => "entries",
        enum: $ => "enum",
        error: $ => "error",
        exit: $ => "exit",
        extern: $ => "extern",
        false: $ => "false",
        header: $ => "header",
        header_union: $ => "header_union",
        if: $ => "if",
        in: $ => "in",
        inout: $ => "inout",
        int: $ => "int",
        key: $ => "key",
        match_kind: $ => "match_kind",
        type: $ => "type",
        out: $ => "out",
        parser: $ => "parser",
        package: $ => "package",
        pragma: $ => "pragma",
        return: $ => "return",
        select: $ => "select",
        state: $ => "state",
        string: $ => "string",
        struct: $ => "struct",
        switch: $ => "switch",
        table: $ => "table",
        transition: $ => "transition",
        true: $ => "true",
        tuple: $ => "tuple",
        typedef: $ => "typedef",
        varbit: $ => "varbit",
        valueset: $ => "valueset",
        void: $ => "void",
        identifier: $ => /[a-z_]+/,
        type_identifier: $ => /[a-z]+/,
        string_literal: $ => /".*"/,
        integer: $ => /[0-9]+/,

    },
}
);

/*
p4program
    : // empty
    | p4program declaration
    | p4program ';'  // empty declaration
    ;

declaration
    : constantDeclaration
    | externDeclaration
    | actionDeclaration
    | parserDeclaration
    | typeDeclaration
    | controlDeclaration
    | instantiation
    | errorDeclaration
    | matchKindDeclaration
    | functionDeclaration
    ;

nonTypeName
    : IDENTIFIER
    | APPLY
    | KEY
    | ACTIONS
    | STATE
    | ENTRIES
    | TYPE
    ;

name
    : nonTypeName
    | TYPE_IDENTIFIER
    ;

nonTableKwName
   : IDENTIFIER
   | TYPE_IDENTIFIER
   | APPLY
   | STATE
   | TYPE
   ;

optAnnotations
    : // empty
    | annotations
    ;

annotations
    : annotation
    | annotations annotation
    ;

annotation
    : '@' name
    | '@' name '(' annotationBody ')'
    | '@' name '[' structuredAnnotationBody ']'
    ;

parameterList
    : // empty
    | nonEmptyParameterList
    ;

nonEmptyParameterList
    : parameter
    | nonEmptyParameterList ',' parameter
    ;

parameter
    : optAnnotations direction typeRef name
    | optAnnotations direction typeRef name '=' expression
    ;

direction
    : IN
    | OUT
    | INOUT
    | // empty
    ;

packageTypeDeclaration
    : optAnnotations PACKAGE name optTypeParameters
      '(' parameterList ')'
    ;

instantiation
    : typeRef '(' argumentList ')' name ';'
    | annotations typeRef '(' argumentList ')' name ';'
    | annotations typeRef '(' argumentList ')' name '=' objInitializer ';'
    | typeRef '(' argumentList ')' name '=' objInitializer ';'
    ;

objInitializer
    : '{' objDeclarations '}'
    ;

objDeclarations
    : // empty
    | objDeclarations objDeclaration
    ;

objDeclaration
    : functionDeclaration
    | instantiation
    ;

optConstructorParameters
    : // empty
    | '(' parameterList ')'
    ;

dotPrefix
    : '.'
    ;

// PARSER

parserDeclaration
    : parserTypeDeclaration optConstructorParameters
      // no type parameters allowed in the parserTypeDeclaration
      '{' parserLocalElements parserStates '}'
    ;

parserLocalElements
    : // empty
    | parserLocalElements parserLocalElement
    ;

parserLocalElement
    : constantDeclaration
    | variableDeclaration
    | instantiation
    | valueSetDeclaration
    ;

parserTypeDeclaration
    : optAnnotations PARSER name optTypeParameters '(' parameterList ')'
    ;

parserStates
    : parserState
    | parserStates parserState
    ;

parserState
    : optAnnotations STATE name '{' parserStatements transitionStatement '}'
    ;

parserStatements
    : // empty
    | parserStatements parserStatement
    ;

parserStatement
    : assignmentOrMethodCallStatement
    | directApplication
    | parserBlockStatement
    | constantDeclaration
    | variableDeclaration
    | emptyStatement
    | conditionalStatement
    ;

parserBlockStatement
    : optAnnotations '{' parserStatements '}'
    ;

transitionStatement
    : // empty
    | TRANSITION stateExpression
    ;

stateExpression
    : name ';'
    | selectExpression
    ;

selectExpression
    : SELECT '(' expressionList ')' '{' selectCaseList '}'
    ;

selectCaseList
    : // empty
    | selectCaseList selectCase
    ;

selectCase
    : keysetExpression ':' name ';'
    ;

keysetExpression
    : tupleKeysetExpression
    | simpleKeysetExpression
    ;

tupleKeysetExpression
    : "(" simpleKeysetExpression "," simpleExpressionList ")"
    | "(" reducedSimpleKeysetExpression ")"
    ;

simpleExpressionList
    : simpleKeysetExpression
    | simpleExpressionList ',' simpleKeysetExpression
    ;

reducedSimpleKeysetExpression
    : expression "&&&" expression
    | expression ".." expression
    | DEFAULT
    | "_"
    ;

simpleKeysetExpression
    : expression
    | DEFAULT
    | DONTCARE
    | expression MASK expression
    | expression RANGE expression
    ;

valueSetDeclaration
  : optAnnotations
      VALUESET '<' baseType '>' '(' expression ')' name ';'
  | optAnnotations
      VALUESET '<' tupleType '>' '(' expression ')' name ';'
  | optAnnotations
      VALUESET '<' typeName '>' '(' expression ')' name ';'
  ;

// CONTROL

controlDeclaration
    : controlTypeDeclaration optConstructorParameters
      // no type parameters allowed in controlTypeDeclaration 
      '{' controlLocalDeclarations APPLY controlBody '}'
    ;

controlTypeDeclaration
    : optAnnotations CONTROL name optTypeParameters
      '(' parameterList ')'
    ;

controlLocalDeclarations
    : // empty
    | controlLocalDeclarations controlLocalDeclaration
    ;

controlLocalDeclaration
    : constantDeclaration
    | actionDeclaration
    | tableDeclaration
    | instantiation
    | variableDeclaration
    ;

controlBody
    : blockStatement
    ;

// Extern

externDeclaration
    : optAnnotations EXTERN nonTypeName optTypeParameters '{' methodPrototypes '}'
    | optAnnotations EXTERN functionPrototype ';'
    ;

methodPrototypes
    : // empty
    | methodPrototypes methodPrototype
    ;

functionPrototype
    : typeOrVoid name optTypeParameters '(' parameterList ')'
    ;

methodPrototype
    : optAnnotations functionPrototype ';'
    | optAnnotations TYPE_IDENTIFIER '(' parameterList ')' ';'
    ;

// TYPES

typeRef
    : baseType
    | typeName
    | specializedType
    | headerStackType
    | tupleType
    ;

namedType
    : typeName
    | specializedType
    ;

prefixedType
    : TYPE_IDENTIFIER
    | dotPrefix TYPE_IDENTIFIER
    ;

typeName
    : prefixedType
    ;

tupleType
    : TUPLE '<' typeArgumentList '>'
    ;

headerStackType
    : typeName '[' expression ']'
    | specializedType '[' expression ']'
    ;

specializedType
    : prefixedType '<' typeArgumentList '>'
    ;

baseType
    : BOOL
    | ERROR
    | STRING
    | INT
    | BIT
    | BIT '<' INTEGER '>'
    | INT '<' INTEGER '>'
    | VARBIT '<' INTEGER '>'
    | BIT '<' '(' expression ')' '>'
    | INT '<' '(' expression ')' '>'
    | VARBIT '<' '(' expression ')' '>'
    ;

typeOrVoid
    : typeRef
    | VOID
    | IDENTIFIER     // may be a type variable
    ;

optTypeParameters
    : // empty
    | typeParameters
    ;

typeParameters
    : '<' typeParameterList '>'
    ;

typeParameterList
    : name
    | typeParameterList ',' name
    ;

realTypeArg
    : DONTCARE
    | typeRef
    | VOID
    ;

typeArg
    : DONTCARE
    | typeRef
    | nonTypeName
    | VOID
    ;

realTypeArgumentList
    : realTypeArg
    | realTypeArgumentList COMMA typeArg
    ;

typeArgumentList
    : // empty
    | typeArg
    | typeArgumentList ',' typeArg
    ;

typeDeclaration
    : derivedTypeDeclaration
    | typedefDeclaration
    | parserTypeDeclaration ';'
    | controlTypeDeclaration ';'
    | packageTypeDeclaration ';'
    ;

derivedTypeDeclaration
    : headerTypeDeclaration
    | headerUnionDeclaration
    | structTypeDeclaration
    | enumDeclaration
    ;

headerTypeDeclaration
    : optAnnotations HEADER name optTypeParameters '{' structFieldList '}'
    ;

headerUnionDeclaration
    : optAnnotations HEADER_UNION name optTypeParameters '{' structFieldList '}'
    ;

structTypeDeclaration
    : optAnnotations STRUCT name optTypeParameters '{' structFieldList '}'
    ;

structFieldList
    : // empty
    | structFieldList structField
    ;

structField
    : optAnnotations typeRef name ';'
    ;

enumDeclaration
    : optAnnotations ENUM name '{' identifierList '}'
    | optAnnotations ENUM typeRef name '{' specifiedIdentifierList '}'
    ;

errorDeclaration
    : ERROR '{' identifierList '}'
    ;

matchKindDeclaration
    : MATCH_KIND '{' identifierList '}'
    ;

identifierList
    : name
    | identifierList ',' name
    ;

specifiedIdentifierList
    : specifiedIdentifier
    | specifiedIdentifierList ',' specifiedIdentifier
    ;

specifiedIdentifier
    : name '=' initializer
    ;

typedefDeclaration
    : optAnnotations TYPEDEF typeRef name ';'
    | optAnnotations TYPEDEF derivedTypeDeclaration name ';'
    | optAnnotations TYPE typeRef name ';'
    | optAnnotations TYPE derivedTypeDeclaration name ';'
    ;

// Statements

assignmentOrMethodCallStatement
    : lvalue '(' argumentList ')' ';'
    | lvalue '<' typeArgumentList '>' '(' argumentList ')' ';'
    | lvalue '='  expression ';'
    ;

emptyStatement
    : ';'
    ;

returnStatement
    : RETURN ';'
    | RETURN expression ';'
    ;

exitStatement
    : EXIT ';'
    ;

conditionalStatement
    : IF '(' expression ')' statement
    | IF '(' expression ')' statement ELSE statement
    ;

// To support direct invocation of a control or parser without instantiation
directApplication
    : typeName '.' APPLY '(' argumentList ')' ';'
    ;

statement
    : assignmentOrMethodCallStatement
    | directApplication
    | conditionalStatement
    | emptyStatement
    | blockStatement
    | exitStatement
    | returnStatement
    | switchStatement
    ;

blockStatement
    : optAnnotations '{' statOrDeclList '}'
    ;

statOrDeclList
    : // empty
    | statOrDeclList statementOrDeclaration
    ;

switchStatement
    : SWITCH '(' expression ')' '{' switchCases '}'
    ;

switchCases
    : // empty
    | switchCases switchCase
    ;

switchCase
    : switchLabel ':' blockStatement
    | switchLabel ':'
    ;

switchLabel
    : DEFAULT
    | nonBraceExpression
    ;

statementOrDeclaration
    : variableDeclaration
    | constantDeclaration
    | statement
    | instantiation
    ;

// Tables
tableDeclaration
    : optAnnotations TABLE name '{' tablePropertyList '}'
    ;

tablePropertyList
    : tableProperty
    | tablePropertyList tableProperty
    ;

tableProperty
    : KEY '=' '{' keyElementList '}'
    | ACTIONS '=' '{' actionList '}'
    | optAnnotations CONST ENTRIES '=' '{' entriesList '}' // immutable entries
    | optAnnotations CONST nonTableKwName '=' initializer ';'
    | optAnnotations nonTableKwName '=' initializer ';'
    ;

keyElementList
    : // empty
    | keyElementList keyElement
    ;

keyElement
    : expression ':' name optAnnotations ';'
    ;

actionList
    : // empty
    | actionList optAnnotations actionRef ';'
    ;

actionRef
    : prefixedNonTypeName
    | prefixedNonTypeName '(' argumentList ')'
    ;

entriesList
    : entry
    | entriesList entry
    ;

entry
    : keysetExpression ':' actionRef optAnnotations ';'
    ;

// Action

actionDeclaration
    : optAnnotations ACTION name '(' parameterList ')' blockStatement
    ;

// Variables

variableDeclaration
    : annotations typeRef name optInitializer ';'
    | typeRef name optInitializer ';'
    ;

constantDeclaration
    : optAnnotations CONST typeRef name '=' initializer ';'
    ;

optInitializer
    : // empty
    | '=' initializer
    ;

initializer
    : expression
    ;

// Expressions

functionDeclaration
    : functionPrototype blockStatement
    ;

argumentList
    : // empty
    | nonEmptyArgList
    ;

nonEmptyArgList
    : argument
    | nonEmptyArgList ',' argument
    ;

argument
    : expression
    | name '=' expression
    | DONTCARE
    ;

kvList
    : kvPair
    | kvList ',' kvPair
    ;

kvPair
    : name '=' expression
    ;

expressionList
    : // empty
    | expression
    | expressionList ',' expression
    ;


annotationBody
    : // empty
    | annotationBody '(' annotationBody ')'
    | annotationBody annotationToken
    ;

structuredAnnotationBody
    : expressionList
    | kvList
    ;

annotationToken
    : ABSTRACT
    | ACTION
    | ACTIONS
    | APPLY
    | BOOL
    | BIT
    | CONST
    | CONTROL
    | DEFAULT
    | ELSE
    | ENTRIES
    | ENUM
    | ERROR
    | EXIT
    | EXTERN
    | FALSE
    | HEADER
    | HEADER_UNION
    | IF
    | IN
    | INOUT
    | INT
    | KEY
    | MATCH_KIND
    | TYPE
    | OUT
    | PARSER
    | PACKAGE
    | PRAGMA
    | RETURN
    | SELECT
    | STATE
    | STRING
    | STRUCT
    | SWITCH
    | TABLE
    | TRANSITION
    | TRUE
    | TUPLE
    | TYPEDEF
    | VARBIT
    | VALUESET
    | VOID
    | "_"
    | IDENTIFIER
    | TYPE_IDENTIFIER
    | STRING_LITERAL
    | INTEGER
    | "&&&"
    | ".."
    | "<<"
    | "&&"
    | "||"
    | "=="
    | "!="
    | ">="
    | "<="
    | "++"
    | "+"
    | "|+|"
    | "-"
    | "|-|"
    | "*"
    | "/"
    | "%"
    | "|"
    | "&"
    | "^"
    | "~"
    | "["
    | "]"
    | "{"
    | "}"
    | "<"
    | ">"
    | "!"
    | ":"
    | ","
    | "?"
    | "."
    | "="
    | ";"
    | "@"
    | UNKNOWN_TOKEN
    ;

member
    : name
    ;

prefixedNonTypeName
    : nonTypeName
    | dotPrefix nonTypeName
    ;

lvalue
    : prefixedNonTypeName
    | THIS
    | lvalue '.' member
    | lvalue '[' expression ']'
    | lvalue '[' expression ':' expression ']'
    ;

%left ','
%nonassoc '?'
%nonassoc ':'
%left '||'
%left '&&'
%left '==' '!='
%left '<' '>' '<=' '>='
%left '|'
%left '^'
%left '&'
%left '<<' '>>'
%left '++' '+' '-' '|+|' '|-|'
%left '*' '/' '%'
%right PREFIX
%nonassoc ']' '(' '['
%left '.'

// Additional precedences need to be specified

expression
    : INTEGER
    | TRUE
    | FALSE
    | THIS
    | STRING_LITERAL
    | nonTypeName
    | dotPrefix nonTypeName
    | expression '[' expression ']'
    | expression '[' expression ':' expression ']'
    | '{' expressionList '}'
    | '{' kvList '}'
    | '(' expression ')'
    | '!' expression %prec PREFIX
    | '~' expression %prec PREFIX
    | '-' expression %prec PREFIX
    | '+' expression %prec PREFIX
    | typeName '.' member
    | ERROR '.' member
    | expression '.' member
    | expression '*' expression
    | expression '/' expression
    | expression '%' expression
    | expression '+' expression
    | expression '-' expression
    | expression '|+|' expression
    | expression '|-|' expression
    | expression '<<' expression
    | expression '>>' expression
    | expression '<=' expression
    | expression '>=' expression
    | expression '<' expression
    | expression '>' expression
    | expression '!=' expression
    | expression '==' expression
    | expression '&' expression
    | expression '^' expression
    | expression '|' expression
    | expression '++' expression
    | expression '&&' expression
    | expression '||' expression
    | expression '?' expression ':' expression
    | expression '<' realTypeArgumentList '>' '(' argumentList ')'
    | expression '(' argumentList ')'
    | namedType '(' argumentList ')'
    | '(' typeRef ')' expression
    ;

nonBraceExpression
    : INTEGER
    | STRING_LITERAL
    | TRUE
    | FALSE
    | THIS
    | nonTypeName
    | dotPrefix nonTypeName
    | nonBraceExpression '[' expression ']'
    | nonBraceExpression '[' expression ':' expression ']'
    | '(' expression ')'
    | '!' expression %prec PREFIX
    | '~' expression %prec PREFIX
    | '-' expression %prec PREFIX
    | '+' expression %prec PREFIX
    | typeName '.' member
    | ERROR '.' member
    | nonBraceExpression '.' member
    | nonBraceExpression '*' expression
    | nonBraceExpression '/' expression
    | nonBraceExpression '%' expression
    | nonBraceExpression '+' expression
    | nonBraceExpression '-' expression
    | nonBraceExpression '|+|' expression
    | nonBraceExpression '|-|' expression
    | nonBraceExpression '<<' expression
    | nonBraceExpression '>>' expression
    | nonBraceExpression '<=' expression
    | nonBraceExpression '>=' expression
    | nonBraceExpression '<' expression
    | nonBraceExpression '>' expression
    | nonBraceExpression '!=' expression
    | nonBraceExpression '==' expression
    | nonBraceExpression '&' expression
    | nonBraceExpression '^' expression
    | nonBraceExpression '|' expression
    | nonBraceExpression '++' expression
    | nonBraceExpression '&&' expression
    | nonBraceExpression '||' expression
    | nonBraceExpression '?' expression ':' expression
    | nonBraceExpression '<' realTypeArgumentList '>' '(' argumentList ')'
    | nonBraceExpression '(' argumentList ')'
    | namedType '(' argumentList ')'
    | '(' typeRef ')' expression
    ;
*/
