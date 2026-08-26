<?php

namespace App\Exceptions;

use RuntimeException;

class BookingScheduleException extends RuntimeException
{
    public function __construct(string $message, public readonly int $httpStatus = 422)
    {
        parent::__construct($message);
    }
}
