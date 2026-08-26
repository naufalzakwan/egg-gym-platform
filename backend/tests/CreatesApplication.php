<?php

namespace Tests;

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Application;
use RuntimeException;

trait CreatesApplication
{
    /**
     * Creates the application.
     */
    public function createApplication(): Application
    {
        $app = require __DIR__.'/../bootstrap/app.php';

        $app->make(Kernel::class)->bootstrap();

        $database = (string) $app['db']->connection()->getDatabaseName();
        if (! str_ends_with($database, '_test')) {
            throw new RuntimeException(
                "Test dibatalkan: database '{$database}' bukan database khusus dengan suffix _test."
            );
        }

        return $app;
    }
}
