<?php

namespace App\Http\Controllers\Api\V1\Trainer;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class TrainerDisplayPhotoController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'display_photo' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png', 'max:5120'],
        ]);
        $profile = $request->user()->trainerProfile;
        if (! $profile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $path = $validated['display_photo']->store('trainer-display-photos', 'public');
        $previous = $profile->display_photo_path;
        $profile->update(['display_photo_path' => $path]);
        $this->deleteStoredFile($previous);

        return response()->json([
            'success' => true,
            'message' => 'Foto tampilan trainer berhasil diperbarui.',
            'data' => ['display_photo_path' => $path],
            'meta' => null,
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $profile = $request->user()->trainerProfile;
        if (! $profile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $previous = $profile->display_photo_path;
        $profile->update(['display_photo_path' => null]);
        $this->deleteStoredFile($previous);

        return response()->json([
            'success' => true,
            'message' => 'Foto tampilan trainer berhasil dihapus.',
            'data' => ['display_photo_path' => null],
            'meta' => null,
        ]);
    }

    private function deleteStoredFile(?string $path): void
    {
        if ($path === null || $path === '' || str_starts_with($path, 'http')) {
            return;
        }
        Storage::disk('public')->delete($path);
    }
}
