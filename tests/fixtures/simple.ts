import { Something } from './other';

interface MyInterface {
    field: string;
    method(): void;
}

class MyClass implements MyInterface {
    field: string = '';

    method(): void {
        console.log('Hello');
    }
}

function helper() {
    return new MyClass();
}

export const instance = helper();
