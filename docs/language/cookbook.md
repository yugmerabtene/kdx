# Cookbook

Practical patterns for common KodPix tasks.

## Add Two Numbers

```kodpix
function int add(int a, int b) {
    return a + b;
}
```

## Increment Counter

```kodpix
function int main() {
    int i = 1;
    i++;
    i++;
    return i;
}
```

## Conditional Return

```kodpix
function int main() {
    int x = 0;
    if (x == 0) {
        return 0;
    }
    return 1;
}
```

## While Loop

```kodpix
function int main() {
    int x = 0;
    while (x < 3) {
        x++;
    }
    return x;
}
```

## Class Main Entrypoint

```kodpix
class Main {
    public void main() {
        println("hello");
        return;
    }
}
```
