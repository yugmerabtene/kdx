# Language Reference

This document defines the currently supported KodPix syntax.

## Program Structure

- Top-level functions
- Class blocks (entrypoint bridge through `Main.main`)

## Function Declarations

Supported forms:

```kodpix
function int add(int a, int b) {
    return a + b;
}
```

```kodpix
function main(a: int, b: int) -> int {
    return a + b;
}
```

## Parameters

- Preferred: `type name`
- Compatibility: `name: type`

## Types

- `int`, `float`, `string`, `boolean`, `char`, `void`

## Statements

- Variable declaration: `type name = expr;`
- Array declaration: `type[] name;`
- Return: `return expr;`
- Branching: `if (...) { ... } else { ... }`
- Looping: `while (...) { ... }`, `for (...; ...; ...) { ... }`
- Switch (minimal): `switch (expr) { case v: ... default: ... }`

## Operators

- Arithmetic: `+ - * / %`
- Comparison: `== != < <= > >= === !==`
- Logical: `&& || !`
- Increment: `i++`, `i--`

## Entry Point

Supported entry forms:

```kodpix
function int main() {
    return 0;
}
```

```kodpix
class Main {
    public void main() {
        return;
    }
}
```

## Notes

- Semicolons are required.
- Conditions are intended to be boolean-strict.
