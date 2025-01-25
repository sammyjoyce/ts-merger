export interface Order {
    id: string;
    items: OrderItem[];
    total: number;
    status: OrderStatus;
    createdAt: Date;
    updatedAt: Date;
}

export interface OrderItem {
    productId: string;
    quantity: number;
    price: number;
}

export enum OrderStatus {
    Created = 'created',
    Processing = 'processing',
    Shipped = 'shipped',
    Delivered = 'delivered',
    Cancelled = 'cancelled'
}

export class OrderService {
    private static instance: OrderService;
    private orders: Map<string, Order>;

    private constructor() {
        this.orders = new Map();
    }

    static getInstance(): OrderService {
        if (!OrderService.instance) {
            OrderService.instance = new OrderService();
        }
        return OrderService.instance;
    }

    createOrder(items: OrderItem[]): Order {
        const order: Order = {
            id: Math.random().toString(36).substring(2) + Date.now().toString(36),
            items,
            total: items.reduce((sum, item) => sum + item.price * item.quantity, 0),
            status: OrderStatus.Created,
            createdAt: new Date(),
            updatedAt: new Date()
        };

        this.orders.set(order.id, order);
        return order;
    }

    getOrder(id: string): Order | undefined {
        return this.orders.get(id);
    }

    updateOrderStatus(id: string, status: OrderStatus): Order {
        const order = this.orders.get(id);
        if (!order) {
            throw new Error(`Order ${id} not found`);
        }

        order.status = status;
        order.updatedAt = new Date();
        this.orders.set(id, order);
        return order;
    }

    listOrders(): Order[] {
        return Array.from(this.orders.values());
    }

    cancelOrder(id: string): Order {
        return this.updateOrderStatus(id, OrderStatus.Cancelled);
    }
}
