<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login Administrator - Kasir Pro</title>
    <link rel="icon" type="image/png" href="{{ asset('icon.png') }}">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #144683;
            --primary-active: #103969;
            --secondary: #FE7E00;
            --surface: #F8FAFC;
            --card: #FFFFFF;
            --divider: #E5E7EB;
            --text-primary: #111827;
            --text-secondary: #6B7280;
            --error: #DC2626;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--surface);
            color: var(--text-primary);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .login-card {
            background-color: var(--card);
            border-radius: 24px;
            border: 1px solid var(--divider);
            padding: 40px;
            width: 100%;
            max-width: 440px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.02);
        }

        .login-logo {
            display: flex;
            justify-content: center;
            margin-bottom: 24px;
        }

        .login-title {
            font-size: 24px;
            font-weight: 700;
            text-align: center;
            color: var(--primary);
            margin-bottom: 8px;
        }

        .login-subtitle {
            font-size: 14px;
            color: var(--text-secondary);
            text-align: center;
            margin-bottom: 32px;
        }

        .form-group {
            margin-bottom: 20px;
        }

        .form-label {
            display: block;
            margin-bottom: 8px;
            font-size: 14px;
            font-weight: 500;
        }

        .form-control {
            width: 100%;
            padding: 12px 16px;
            border-radius: 12px;
            border: 1px solid var(--divider);
            background-color: var(--surface);
            font-family: inherit;
            font-size: 14px;
            color: var(--text-primary);
            transition: all 0.2s ease;
        }

        .form-control:focus {
            outline: none;
            border-color: var(--primary);
            box-shadow: 0 0 0 3px rgba(20, 70, 131, 0.15);
        }

        .btn-login {
            width: 100%;
            background-color: var(--primary);
            color: white;
            padding: 14px;
            font-size: 14px;
            font-weight: 600;
            border: none;
            border-radius: 999px;
            cursor: pointer;
            transition: background-color 0.2s ease;
            margin-top: 12px;
        }

        .btn-login:hover {
            background-color: var(--primary-active);
        }

        .error-alert {
            background-color: #FDE8E8;
            color: #9B1C1C;
            padding: 12px 16px;
            border-radius: 12px;
            font-size: 14px;
            margin-bottom: 24px;
            font-weight: 500;
        }
    </style>
</head>
<body>
    <div class="login-card">
        <div class="login-logo">
            <img src="{{ asset('icon.png') }}" alt="Kasir Pro" style="width: 56px; height: 56px; object-fit: contain; border-radius: 12px;">
        </div>
        <h1 class="login-title">Administrator</h1>
        <p class="login-subtitle">Kasir Pro Management Portal</p>

        @if($errors->any())
            <div class="error-alert">
                {{ $errors->first() }}
            </div>
        @endif

        <form action="{{ route('admin.login') }}" method="POST">
            @csrf
            <div class="form-group">
                <label class="form-label" for="email">Alamat Email</label>
                <input class="form-control" type="email" id="email" name="email" value="{{ old('email') }}" required placeholder="nama@perusahaan.com" autofocus>
            </div>
            
            <div class="form-group">
                <label class="form-label" for="password">Password</label>
                <input class="form-control" type="password" id="password" name="password" required placeholder="••••••••">
            </div>

            <button type="submit" class="btn-login">Masuk Dashboard</button>
        </form>
    </div>
</body>
</html>
