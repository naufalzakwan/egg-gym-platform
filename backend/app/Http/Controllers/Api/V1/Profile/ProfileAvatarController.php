<?php

namespace App\Http\Controllers\Api\V1\Profile;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Upload/hapus foto profil (avatar) untuk user yang login.
 *
 * REUSABLE untuk SEMUA role (member & trainer) karena avatar disimpan di kolom
 * `users.avatar_url` (satu sumber untuk kedua role).
 *
 * STRATEGI URL (disepakati): simpan RELATIVE PATH (mis. "avatars/abc.jpg") di
 * `avatar_url`, BUKAN URL absolut. Flutter merangkai baseUrl aktif + path saat
 * render, sehingga foto tidak rusak walau resolver baseUrl pindah IP LAN.
 * Disk: `public` (konsisten dgn payment-proofs & member-progress).
 */
class ProfileAvatarController extends Controller
{
    /** POST /api/v1/profile/avatar */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            // Kompres/resize dilakukan di sisi Flutter (image_picker maxWidth/
            // quality). Batas 5MB sebagai pengaman.
            'avatar' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png', 'max:5120'],
        ]);

        $user = $request->user();

        // Hapus file lama (bila ada & memang file storage, bukan URL eksternal).
        $this->deleteExistingAvatar($user->avatar_url);

        // Simpan relative path (mis. "avatars/xxxx.jpg").
        $path = $request->file('avatar')->store('avatars', 'public');

        $user->update(['avatar_url' => $path]);

        return response()->json([
            'success' => true,
            'message' => 'Foto profil berhasil diperbarui.',
            'data' => [
                // relative path (Flutter rangkai dgn baseUrl aktif) + url_path
                // siap-pakai relatif ke domain (kalau butuh dibuka via browser).
                'avatar_url' => $path,
                'avatar_public_url' => Storage::disk('public')->url($path),
            ],
            'meta' => null,
        ]);
    }

    /** DELETE /api/v1/profile/avatar */
    public function destroy(Request $request): JsonResponse
    {
        $user = $request->user();

        $this->deleteExistingAvatar($user->avatar_url);
        $user->update(['avatar_url' => null]);

        return response()->json([
            'success' => true,
            'message' => 'Foto profil berhasil dihapus.',
            'data' => ['avatar_url' => null],
            'meta' => null,
        ]);
    }

    /**
     * Hapus file avatar lama dari disk public bila nilainya relative path
     * storage. Nilai lama yang berupa URL eksternal (http...) diabaikan
     * (data admin lama yang cuma diisi teks) — tidak dihapus dari disk.
     */
    private function deleteExistingAvatar(?string $current): void
    {
        if ($current === null || $current === '') {
            return;
        }
        if (str_starts_with($current, 'http://') || str_starts_with($current, 'https://')) {
            return; // URL eksternal / data lama, bukan file di disk kita.
        }
        if (Storage::disk('public')->exists($current)) {
            Storage::disk('public')->delete($current);
        }
    }
}
