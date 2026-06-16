<?php

namespace Tests\Feature;

use App\Http\Controllers\PaymentController;
use Tests\TestCase;

class PaymentMethodMappingTest extends TestCase
{
    public function test_default_bank_transfer_option_does_not_force_unavailable_va_method(): void
    {
        $controller = new PaymentController();

        $method = new \ReflectionMethod($controller, 'mapXenditPaymentMethods');
        $method->setAccessible(true);

        $this->assertSame([], $method->invoke($controller, 'btn_va'));
        $this->assertSame(['DANA'], $method->invoke($controller, 'dana'));
        $this->assertSame(['GOPAY'], $method->invoke($controller, 'gopay'));
        $this->assertSame(['SHOPEEPAY'], $method->invoke($controller, 'shopeepay'));
    }
}
