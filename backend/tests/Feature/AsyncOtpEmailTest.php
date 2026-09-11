<?php

namespace Tests\Feature;

use App\Enums\InvoiceStatus;
use App\Enums\SubscriptionStatus;
use App\Enums\TokenStatus;
use App\Mail\DeviceResetOtpMail;
use App\Mail\PasswordResetOtpMail;
use App\Mail\PinResetOtpMail;
use App\Models\Device;
use App\Models\DeviceResetOtp;
use App\Models\Invoice;
use App\Models\InvoiceItem;
use App\Models\LicenseToken;
use App\Models\Package;
use App\Models\PasswordResetOtp;
use App\Models\PinResetOtp;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class AsyncOtpEmailTest extends TestCase
{
    use RefreshDatabase;

    protected User $user;
    protected Tenant $tenant;
    protected LicenseToken $token;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.jwt_secret' => 'test-jwt-secret-key-32-characters-minimum']);

        $this->tenant = Tenant::create([
            'name' => 'Resto Berkah Async',
            'owner_name' => 'Ahmad Kasir',
            'email' => 'ahmad@berkah.com',
            'store_name' => 'Berkah Resto #1',
            'status' => 'active',
        ]);

        $this->user = User::create([
            'tenant_id' => $this->tenant->id,
            'name' => 'Ahmad Kasir',
            'email' => 'ahmad@berkah.com',
            'password' => Hash::make('password123'),
            'pin' => Hash::make('123456'),
            'is_admin' => false,
        ]);

        $package = Package::create([
            'name' => 'Paket Resto Pro',
            'slug' => 'paket-resto-pro',
            'price' => 500000,
            'default_duration_days' => 365,
            'device_limit_per_token' => 1,
            'is_active' => true,
        ]);

        $invoice = Invoice::create([
            'tenant_id' => $this->tenant->id,
            'invoice_number' => 'INV-ASYNC-001',
            'status' => InvoiceStatus::PAID,
            'subtotal' => 500000,
            'total_amount' => 500000,
        ]);

        $item = InvoiceItem::create([
            'invoice_id' => $invoice->id,
            'package_id' => $package->id,
            'package_name' => $package->name,
            'quantity' => 1,
            'unit_price' => 500000,
            'total_price' => 500000,
            'duration_days' => 365,
        ]);

        $subscription = Subscription::create([
            'tenant_id' => $this->tenant->id,
            'package_id' => $package->id,
            'package_name' => $package->name,
            'invoice_item_id' => $item->id,
            'status' => SubscriptionStatus::ACTIVE,
            'start_date' => now(),
            'expiry_date' => now()->addYear(),
        ]);

        $this->token = LicenseToken::create([
            'tenant_id' => $this->tenant->id,
            'subscription_id' => $subscription->id,
            'token_key' => 'TOK-ASYNC-DEVICE-001',
            'server_secret' => 'secret_async_123',
            'status' => TokenStatus::ACTIVE,
        ]);
    }

    public function test_mailables_implement_should_queue_and_have_retry_configuration(): void
    {
        $pinMail = new PinResetOtpMail('123456', 'Ahmad');
        $this->assertInstanceOf(ShouldQueue::class, $pinMail);
        $this->assertEquals(3, $pinMail->tries);
        $this->assertEquals([5, 15, 30], $pinMail->backoff);
        $this->assertEquals(30, $pinMail->timeout);

        $passwordMail = new PasswordResetOtpMail('654321', 'Ahmad');
        $this->assertInstanceOf(ShouldQueue::class, $passwordMail);
        $this->assertEquals(3, $passwordMail->tries);
        $this->assertEquals([5, 15, 30], $passwordMail->backoff);
        $this->assertEquals(30, $passwordMail->timeout);

        $deviceMail = new DeviceResetOtpMail('112233', 'Ahmad');
        $this->assertInstanceOf(ShouldQueue::class, $deviceMail);
        $this->assertEquals(3, $deviceMail->tries);
        $this->assertEquals([5, 15, 30], $deviceMail->backoff);
        $this->assertEquals(30, $deviceMail->timeout);
    }

    public function test_pin_reset_otp_is_queued_asynchronously(): void
    {
        Mail::fake();

        $response = $this->postJson('/api/auth/request-otp', [
            'email' => 'ahmad@berkah.com',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Kode OTP telah dikirimkan ke email Anda.');

        // Verify Mail was queued and not sent synchronously
        Mail::assertQueued(PinResetOtpMail::class, function (PinResetOtpMail $mail) {
            return $mail->hasTo('ahmad@berkah.com') &&
                   $mail->userName === 'Ahmad Kasir' &&
                   strlen($mail->otpCode) === 6;
        });

        // Verify database record was created
        $otp = PinResetOtp::where('email', 'ahmad@berkah.com')->latest()->first();
        $this->assertNotNull($otp);
        $this->assertEquals(6, strlen($otp->otp_code));
        $this->assertFalse($otp->is_verified);
    }

    public function test_password_reset_otp_is_queued_asynchronously(): void
    {
        Mail::fake();

        $response = $this->postJson('/api/password/forgot', [
            'email' => 'ahmad@berkah.com',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Kode OTP telah dikirimkan ke email Anda.');

        // Verify Mail was queued
        Mail::assertQueued(PasswordResetOtpMail::class, function (PasswordResetOtpMail $mail) {
            return $mail->hasTo('ahmad@berkah.com') &&
                   $mail->userName === 'Ahmad Kasir' &&
                   strlen($mail->otpCode) === 6;
        });

        $otp = PasswordResetOtp::where('email', 'ahmad@berkah.com')->latest()->first();
        $this->assertNotNull($otp);
        $this->assertEquals(6, strlen($otp->otp_code));
        $this->assertFalse($otp->is_verified);
    }

    public function test_device_reset_otp_is_queued_asynchronously(): void
    {
        Mail::fake();

        $response = $this->postJson('/api/auth/request-device-reset-otp', [
            'email' => 'ahmad@berkah.com',
            'password' => 'password123',
            'token_key' => $this->token->token_key,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Kode OTP telah dikirimkan ke email Anda.');

        // Verify Mail was queued
        Mail::assertQueued(DeviceResetOtpMail::class, function (DeviceResetOtpMail $mail) {
            return $mail->hasTo('ahmad@berkah.com') &&
                   $mail->userName === 'Ahmad Kasir' &&
                   strlen($mail->otpCode) === 6;
        });

        $otp = DeviceResetOtp::where('email', 'ahmad@berkah.com')->latest()->first();
        $this->assertNotNull($otp);
        $this->assertEquals($this->token->token_key, $otp->token_key);
        $this->assertEquals(6, strlen($otp->otp_code));
    }

    public function test_pin_recovery_full_flow_with_queued_email(): void
    {
        Mail::fake();

        // 1. Request OTP
        $reqResponse = $this->postJson('/api/auth/request-otp', [
            'email' => 'ahmad@berkah.com',
        ]);
        $reqResponse->assertStatus(200);

        $otpRecord = PinResetOtp::where('email', 'ahmad@berkah.com')->latest()->first();
        $this->assertNotNull($otpRecord);

        // 2. Verify OTP
        $verifyResponse = $this->postJson('/api/auth/verify-otp', [
            'email' => 'ahmad@berkah.com',
            'otp' => $otpRecord->otp_code,
        ]);

        $verifyResponse->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['reset_token']);

        $resetToken = $verifyResponse->json('reset_token');

        // 3. Reset PIN with strong non-sequential PIN
        $resetResponse = $this->postJson('/api/auth/reset-pin', [
            'email' => 'ahmad@berkah.com',
            'reset_token' => $resetToken,
            'new_pin' => '948271',
            'new_pin_confirmation' => '948271',
        ]);

        $resetResponse->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'PIN berhasil diperbarui. Silakan login dengan PIN baru Anda.');

        $this->user->refresh();
        $this->assertTrue(Hash::check('948271', $this->user->pin));
    }
}
