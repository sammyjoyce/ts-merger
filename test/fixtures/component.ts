export interface Component {
    name: string;
    render(): void;
    click(): void;
}

export class Button implements Component {
    constructor(public name: string) {}

    render(): void {
        console.log(`Rendering button: ${this.name}`);
    }

    click(): void {
        console.log(`Button ${this.name} clicked!`);
    }
}
