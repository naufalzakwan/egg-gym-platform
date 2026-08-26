<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminDashboardChartVisibilityTest extends TestCase
{
    use DatabaseTransactions;

    public function test_chart_empty_state_css_respects_hidden_attribute(): void
    {
        $role = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $role->id,
            'name' => 'Dashboard Test Admin',
            'email' => uniqid('dashboard_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('.chart-empty[hidden], .bar-chart[hidden] { display: none; }', false)
            ->assertSee('empty.hidden = hasRevenue;', false)
            ->assertSee("bar.addEventListener('click', () => selectBar(index));", false)
            ->assertSee("bar.classList.toggle('is-active', active);", false)
            ->assertSee("bar.setAttribute('aria-pressed', active ? 'true' : 'false');", false)
            ->assertSee("tip.textContent = points[barIndex].value_label;", false)
            ->assertSee("render('monthly');", false);
    }
}
