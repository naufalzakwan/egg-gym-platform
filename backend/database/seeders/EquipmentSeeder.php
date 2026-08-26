<?php

namespace Database\Seeders;

use App\Models\Equipment;
use Illuminate\Database\Seeder;

class EquipmentSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $equipments = [
            [
                'name' => 'Hi-Performance Treadmill',
                'slug' => 'hi-performance-treadmill',
                'category' => 'Cardio',
                'description' => 'Treadmill untuk endurance, incline walk, dan progressive cardio.',
                'focus' => 'Calves, quads, stamina',
                'stage_label' => 'CARDIO ZONE',
                'usage_window' => '15-30 mins | warm up, incline walk, conditioning',
                'best_for' => 'Fat loss, stamina build, heart rate conditioning',
                'difficulty' => 'Beginner to Advanced',
                'key_benefits_json' => [
                    'Mudah dipakai untuk progressive cardio session.',
                    'Cocok untuk warm up, steady walk, dan sprint finisher.',
                    'Membantu monitor intensitas lewat pace dan incline control.',
                ],
                'usage_flow_json' => [
                    'Mulai dari 5 menit warm up pace ringan.',
                    'Naikkan incline atau pace bertahap sesuai target sesi.',
                    'Akhiri dengan cooldown 3-5 menit agar heart rate turun stabil.',
                ],
                'safety_notes_json' => [
                    'Jaga langkah tetap stabil, jangan langsung lompat ke pace tinggi.',
                    'Pegang side rail hanya saat transisi kecepatan jika perlu.',
                    'Gunakan sepatu latihan yang punya grip baik untuk sesi incline.',
                ],
                'suggested_moves_json' => [
                    'Incline walk finisher',
                    'Sprint interval 30/30',
                    'Steady state recovery cardio',
                ],
                'is_active' => true,
            ],
            [
                'name' => 'Olympic Power Rack',
                'slug' => 'olympic-power-rack',
                'category' => 'Strength',
                'description' => 'Rack utama untuk squat, overhead press, dan bench safety setup.',
                'focus' => 'Full body compound',
                'stage_label' => 'STRENGTH ZONE',
                'usage_window' => '25-60 mins | compound lift, technique, overload block',
                'best_for' => 'Leg day, push day, full body strength programming',
                'difficulty' => 'Intermediate to Advanced',
                'key_benefits_json' => [
                    'Aman untuk heavy squat, press, dan compound lift utama.',
                    'Mudah dipakai untuk setup safety pin dan progressive overload.',
                    'Cocok untuk phase strength, hypertrophy, dan technique session.',
                ],
                'usage_flow_json' => [
                    'Atur safety pin sesuai tinggi gerakan utama.',
                    'Mulai dari empty bar atau warm-up load sebelum top set.',
                    'Catat progres set utama agar progression antar minggu konsisten.',
                ],
                'safety_notes_json' => [
                    'Pastikan ketinggian hook dan safety pin sudah benar sebelum unrack.',
                    'Gunakan collar pengunci saat beban mulai menengah ke atas.',
                    'Jangan skip warm up set sebelum compound movement berat.',
                ],
                'suggested_moves_json' => [
                    'Back squat',
                    'Overhead press',
                    'Rack pull',
                ],
                'is_active' => true,
            ],
            [
                'name' => 'Cable Station',
                'slug' => 'cable-station',
                'category' => 'Functional',
                'description' => 'Latihan pull, push, dan isolation movement dengan resistance stabil.',
                'focus' => 'Back, chest, arms',
                'stage_label' => 'FUNCTIONAL BAY',
                'usage_window' => '20-45 mins | isolation, pull-push, accessory block',
                'best_for' => 'Back detail, chest isolation, arm finishing set',
                'difficulty' => 'Intermediate Friendly',
                'key_benefits_json' => [
                    'Resistance terasa stabil di seluruh range gerak.',
                    'Cocok untuk pull, push, dan unilateral correction work.',
                    'Mudah dipakai untuk finisher atau hypertrophy volume block.',
                ],
                'usage_flow_json' => [
                    'Atur pulley setinggi gerakan yang dibutuhkan.',
                    'Pilih handle yang sesuai: rope, bar, atau single grip.',
                    'Mulai dari load ringan untuk memastikan angle gerakan aman.',
                ],
                'safety_notes_json' => [
                    'Jaga torso stabil dan jangan biarkan momentum menarik badan.',
                    'Pastikan pin beban terkunci sempurna sebelum mulai set.',
                    'Kontrol eccentric phase, jangan lepaskan beban terlalu cepat.',
                ],
                'suggested_moves_json' => [
                    'Seated cable row',
                    'Cable fly',
                    'Straight-arm pulldown',
                ],
                'is_active' => true,
            ],
        ];

        foreach ($equipments as $equipment) {
            Equipment::updateOrCreate(
                ['slug' => $equipment['slug']],
                $equipment
            );
        }
    }
}
