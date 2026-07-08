<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\Channel;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Queue\SerializesModels;

class OrderCancelled implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $order;
    public $buyerId;
    public $sellerId;

    public function __construct(Order $order)
    {
        $this->order = $order;
        $this->buyerId = $order->buyer_id;
        $this->sellerId = $order->seller_id;
    }

    public function broadcastOn()
    {
        return [
            // Notify buyer
            new PrivateChannel('order.' . $this->buyerId),
            // Notify seller
            new PrivateChannel('order.' . $this->sellerId),
            // Notify admin
            new PrivateChannel('admin.orders'),
        ];
    }

    public function broadcastAs()
    {
        return 'order.cancelled';
    }

    public function broadcastWith()
    {
        return [
            'id' => $this->order->id,
            'status' => $this->order->status,
            'buyer_id' => $this->buyerId,
            'seller_id' => $this->sellerId,
            'cancelled_at' => now(),
            'message' => 'Pesanan telah dibatalkan',
        ];
    }
}
