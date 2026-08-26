<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login Admin {{ $appBranding['name'] }}</title>
    <link rel="icon" href="{{ $appBranding['logo_path'] ? asset('storage/'.$appBranding['logo_path']).'?v='.$appBranding['logo_version'] : asset('favicon.ico') }}">
    <style>
        body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            background: #0f1115;
            color: #f4f7fb;
            font-family: Arial, Helvetica, sans-serif;
        }
        .card {
            width: min(420px, calc(100vw - 32px));
            background: #171a21;
            border: 1px solid #2b3242;
            border-radius: 20px;
            padding: 28px;
        }
        h1 {
            margin: 0 0 8px;
            color: #f4c95d;
        }
        p {
            margin: 0 0 24px;
            color: #aeb7c6;
            line-height: 1.5;
        }
        .field {
            display: flex;
            flex-direction: column;
            gap: 8px;
            margin-bottom: 16px;
        }
        label {
            font-weight: 700;
        }
        input {
            padding: 12px 14px;
            border-radius: 12px;
            border: 1px solid #2b3242;
            background: #202531;
            color: #f4f7fb;
            font: inherit;
        }
        .error {
            color: #ffc3c3;
            font-size: 13px;
            margin-top: 4px;
        }
        button {
            width: 100%;
            padding: 12px 14px;
            border: 0;
            border-radius: 12px;
            background: #f4c95d;
            color: #111;
            font-weight: 700;
            cursor: pointer;
        }
        .brand-logo { width: 72px; height: 72px; object-fit: contain; border-radius: 14px; margin-bottom: 14px; }
    </style>
</head>
<body>
    <form class="card" method="POST" action="{{ route('admin.login.submit') }}">
        @csrf
        @if($appBranding['logo_path'])<img class="brand-logo" src="{{ asset('storage/'.$appBranding['logo_path']) }}?v={{ $appBranding['logo_version'] }}" alt="Logo {{ $appBranding['name'] }}" onerror="this.hidden=true">@endif
        <h1>Admin {{ $appBranding['name'] }}</h1>
        <p>Masuk sebagai admin untuk mengelola master data operasional web admin.</p>

        <div class="field">
            <label for="email">Email</label>
            <input id="email" type="email" name="email" value="{{ old('email') }}" required autofocus>
            @error('email')
                <div class="error">{{ $message }}</div>
            @enderror
        </div>

        <div class="field">
            <label for="password">Password</label>
            <input id="password" type="password" name="password" required>
            @error('password')
                <div class="error">{{ $message }}</div>
            @enderror
        </div>

        <button type="submit">Masuk ke Admin</button>
    </form>
</body>
</html>
