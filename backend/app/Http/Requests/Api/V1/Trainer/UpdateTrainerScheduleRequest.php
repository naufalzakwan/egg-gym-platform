<?php

namespace App\Http\Requests\Api\V1\Trainer;

use App\Models\GymOperationHour;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class UpdateTrainerScheduleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'days' => ['required', 'array', 'size:7'],
            'days.*' => ['required', 'array:day_of_week,enabled,shifts'],
            'days.*.day_of_week' => ['required', 'integer', 'between:1,7', 'distinct'],
            'days.*.enabled' => ['required', 'boolean'],
            'days.*.shifts' => ['present', 'array'],
            'days.*.shifts.*' => ['required', 'array:start_time,end_time'],
            'days.*.shifts.*.start_time' => ['required', 'date_format:H:i'],
            'days.*.shifts.*.end_time' => ['required', 'date_format:H:i'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }

            $operationHours = GymOperationHour::query()
                ->whereIn('day_order', range(1, 7))
                ->get()
                ->keyBy('day_order');

            foreach ($this->input('days', []) as $dayIndex => $day) {
                $shifts = $day['shifts'];
                $enabled = (bool) $day['enabled'];

                if ($enabled && count($shifts) === 0) {
                    $validator->errors()->add("days.$dayIndex.shifts", 'Hari aktif harus memiliki minimal satu shift.');
                }
                if (! $enabled && count($shifts) > 0) {
                    $validator->errors()->add("days.$dayIndex.shifts", 'Hari nonaktif tidak boleh memiliki shift.');
                }
                if (! $enabled) {
                    continue;
                }

                $operation = $operationHours->get((int) $day['day_of_week']);
                if (! $operation || $operation->is_closed || ! $operation->open_time || ! $operation->close_time) {
                    $validator->errors()->add("days.$dayIndex.enabled", 'Jadwal tidak dapat diaktifkan saat gym tutup atau jam operasional belum tersedia.');

                    continue;
                }

                $normalized = [];
                foreach ($shifts as $shiftIndex => $shift) {
                    [$startHour, $startMinute] = array_map('intval', explode(':', $shift['start_time']));
                    [$endHour, $endMinute] = array_map('intval', explode(':', $shift['end_time']));
                    $start = $startHour * 60 + $startMinute;
                    $end = $endHour * 60 + $endMinute;

                    if ($startMinute % 30 !== 0 || $endMinute % 30 !== 0) {
                        $validator->errors()->add("days.$dayIndex.shifts.$shiftIndex", 'Jam shift harus berada pada batas 30 menit.');
                    }
                    if ($end <= $start) {
                        $validator->errors()->add("days.$dayIndex.shifts.$shiftIndex.end_time", 'Jam selesai harus setelah jam mulai.');
                    }
                    if ($operation->open_time > $shift['start_time'].':00' || $operation->close_time < $shift['end_time'].':00') {
                        $validator->errors()->add("days.$dayIndex.shifts.$shiftIndex", 'Shift harus berada dalam jam operasional gym.');
                    }

                    $normalized[] = [$start, $end, $shiftIndex];
                }

                usort($normalized, fn (array $a, array $b) => $a[0] <=> $b[0]);
                for ($i = 1; $i < count($normalized); $i++) {
                    if ($normalized[$i][0] < $normalized[$i - 1][1]) {
                        $validator->errors()->add(
                            "days.$dayIndex.shifts.{$normalized[$i][2]}",
                            'Shift pada hari yang sama tidak boleh tumpang tindih.'
                        );
                    }
                }
            }
        });
    }
}
