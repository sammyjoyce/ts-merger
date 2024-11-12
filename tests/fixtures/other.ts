export class Something {
    value: number = 42;

    getValue(): number {
        return this.value;
    }
}

export interface OtherInterface {
    something: Something;
}

export function createSomething(): Something {
    return new Something();
}
