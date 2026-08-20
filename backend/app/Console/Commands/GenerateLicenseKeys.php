<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('license:keys')]
#[Description('Generate RSA key pair for JWT Offline Token signing')]
class GenerateLicenseKeys extends Command
{
    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->info('Generating RSA key pair for License JWT...');

        $config = [
            "digest_alg" => "sha256",
            "private_key_bits" => 2048,
            "private_key_type" => OPENSSL_KEYTYPE_RSA,
        ];

        // Try to find openssl.cnf for Windows XAMPP environments
        $possibleCnfPaths = [
            'C:\\xampp\\php\\extras\\ssl\\openssl.cnf',
            'C:\\xampp\\apache\\conf\\openssl.cnf',
        ];
        
        foreach ($possibleCnfPaths as $path) {
            if (file_exists($path)) {
                $config["config"] = $path;
                break;
            }
        }

        // Create the private and public key
        $res = openssl_pkey_new($config);
        
        if (!$res) {
            $this->error('Failed to generate key pair. Check your OpenSSL configuration.');
            return Command::FAILURE;
        }

        // Extract the private key
        openssl_pkey_export($res, $privateKey);

        // Extract the public key
        $publicKeyDetails = openssl_pkey_get_details($res);
        $publicKey = $publicKeyDetails["key"];

        // Save to storage path
        $privateKeyPath = storage_path('license-private.key');
        $publicKeyPath = storage_path('license-public.key');

        file_put_contents($privateKeyPath, $privateKey);
        file_put_contents($publicKeyPath, $publicKey);

        $this->info('RSA key pair generated successfully!');
        $this->line('Private Key: ' . $privateKeyPath);
        $this->line('Public Key: ' . $publicKeyPath);

        return Command::SUCCESS;
    }
}
