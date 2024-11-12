// Generic class with multiple type parameters
export class Container<T, U> {
    private items: T[];
    private metadata: Map<string, U>;

    constructor() {
        this.items = [];
        this.metadata = new Map();
    }

    add(item: T, meta: U): void {
        this.items.push(item);
        this.metadata.set(item.toString(), meta);
    }
}

// Interface extending multiple interfaces
interface BaseStorage {
    save(): void;
}

interface Logger {
    log(message: string): void;
}

export interface StorageWithLogging extends BaseStorage, Logger {
    getStorageType(): string;
}

// Abstract class with decorators
@Service()
abstract class BaseService implements StorageWithLogging {
    abstract save(): void;
    abstract getStorageType(): string;
    
    @LogMethod()
    log(message: string): void {
        console.log(`[${this.getStorageType()}]: ${message}`);
    }
}

// Function with complex type parameters
export function processItems<T extends { id: string }>(
    items: T[],
    callback: (item: T) => void
): void {
    items.forEach(callback);
}

// Namespace with nested types
export namespace Storage {
    export interface Config {
        type: string;
        path: string;
    }

    export class FileStorage extends BaseService {
        constructor(private config: Config) {
            super();
        }

        save(): void {
            this.log("Saving to file...");
        }

        getStorageType(): string {
            return "file";
        }
    }
}

// Type aliases and mapped types
type StorageType = "file" | "memory" | "network";
type StorageConfig<T extends StorageType> = {
    [K in T]: Storage.Config;
};
