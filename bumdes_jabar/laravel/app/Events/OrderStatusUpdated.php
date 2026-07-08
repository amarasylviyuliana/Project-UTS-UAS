<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Queue\SerializesModels;

class OrderStatusUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $order;
    public $previousStatus;
    public $buyerId;
    public $sellerId;

    public function __construct(Order $order, $previousStatus = null)
    {
        $this->order = $order;
        $this->previousStatus = $previousStatus;
        $this->buyerId = $order->buyer_id;
        $this->sellerId = $order->seller_id;
    }

    public function broadcastOn()
    {
        return [
            new PrivateChannel('order.' . $this->buyerId),
            new PrivateChannel('order.' . $this->sellerId),
            new PrivateChannel('admin.orders'),
        ];
    }

    public function broadcastAs()
    {
        return 'order.status-updated';
    }

    public function broadcastWith()
    {
        return [
            'id' => $this->order->id,
            'status' => $this->order->status,
            'previous_status' => $this->previousStatus,
            'buyer_id' => $this->buyerId,
            'seller_id' => $this->sellerId,
            'updated_at' => $this->order->updated_at,
        ];
    }
}
