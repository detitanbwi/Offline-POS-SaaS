<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Attachment;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

use Illuminate\Support\Facades\Log;
use Throwable;

class PasswordResetOtpMail extends Mailable implements ShouldQueue
{
    use Queueable, SerializesModels;

    /**
     * Jumlah percobaan maksimal jika terjadi kegagalan jaringan/SMTP
     */
    public int $tries = 3;

    /**
     * Waktu tunggu (detik) antar percobaan ulang (exponential backoff)
     */
    public array $backoff = [5, 15, 30];

    /**
     * Timeout per pengiriman (detik)
     */
    public int $timeout = 30;

    public $otpCode;
    public $userName;

    /**
     * Create a new message instance.
     */
    public function __construct($otpCode, $userName)
    {
        $this->otpCode = $otpCode;
        $this->userName = $userName;
    }

    /**
     * Get the message envelope.
     */
    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Kode OTP Reset Password Anda',
        );
    }

    /**
     * Get the message content definition.
     */
    public function content(): Content
    {
        return new Content(
            view: 'emails.password-reset-otp',
        );
    }

    /**
     * Get the attachments for the message.
     *
     * @return array<int, Attachment>
     */
    public function attachments(): array
    {
        return [];
    }

    /**
     * Penanganan jika semua percobaan antrean gagal
     */
    public function failed(Throwable $exception): void
    {
        Log::error("Queue Mailer gagal mengirimkan PasswordResetOtpMail untuk user: {$this->userName}. Error: " . $exception->getMessage());
    }
}
