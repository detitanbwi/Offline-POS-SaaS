<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class PinResetOtpMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $otpCode,
        public string $userName
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Kode OTP Pemulihan PIN POS - Offline POS SaaS',
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.pin-reset-otp',
        );
    }

    public function attachments(): array
    {
        return [];
    }
}
