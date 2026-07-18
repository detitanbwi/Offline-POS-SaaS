<?php

namespace App\Http\Controllers;

use App\Enums\SubscriptionStatus;
use App\Repositories\SubscriptionRepository;

class AdminSubscriptionController extends Controller
{
    public function __construct(
        protected SubscriptionRepository $subscriptionRepository,
    ) {}

    public function index()
    {
        $subscriptions = $this->subscriptionRepository->paginate(request()->only(['search', 'status']));
        $statuses = SubscriptionStatus::cases();

        return view('admin.subscriptions.index', compact('subscriptions', 'statuses'));
    }

    public function show(string $id)
    {
        $subscription = $this->subscriptionRepository->findByIdWithRelations($id);

        return view('admin.subscriptions.show', compact('subscription'));
    }
}
