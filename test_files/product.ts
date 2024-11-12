interface Product {
    id: number;
    name: string;
    price: number;
}

class ProductService {
    private products: Product[] = [];

    addProduct(product: Product): void {
        this.products.push(product);
    }

    getProduct(id: number): Product | undefined {
        return this.products.find(product => product.id === id);
    }

    getProductsByPriceRange(min: number, max: number): Product[] {
        return this.products.filter(product => 
            product.price >= min && product.price <= max
        );
    }
}
