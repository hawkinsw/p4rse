// p4rse, Copyright 2026, Will Hawkins
//
// This file is part of p4rse.
//
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

/// A scope that resolves variable identifiers to their types.
public typealias VarTypeScope = Scope<P4Type>

/// Scopes that resolve variable identifiers to their types.
public typealias VarTypeScopes = Scopes<P4Type>

/// A scope that resolves type identifiers to their types.
public typealias TypeTypeScope = Scope<P4Type>

/// Scopes that resolve type identifiers to their types.
public typealias TypeTypeScopes = Scopes<P4Type>

