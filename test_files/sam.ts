export const thing = 1;

export interface Theme {
    primary: string;
    secondary: string;
    background: string;
}

export class ThemeManager {
    private static instance: ThemeManager;
    private currentTheme: Theme;

    private constructor() {
        this.currentTheme = {
            primary: '#007bff',
            secondary: '#6c757d',
            background: '#ffffff'
        };
    }

    static getInstance(): ThemeManager {
        if (!ThemeManager.instance) {
            ThemeManager.instance = new ThemeManager();
        }
        return ThemeManager.instance;
    }

    getTheme(): Theme {
        return { ...this.currentTheme };
    }

    setTheme(theme: Theme): void {
        this.currentTheme = { ...theme };
    }

    resetTheme(): void {
        this.currentTheme = {
            primary: '#007bff',
            secondary: '#6c757d',
            background: '#ffffff'
        };
    }
}