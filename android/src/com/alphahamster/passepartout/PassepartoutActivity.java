package com.alphahamster.passepartout;

import android.content.Intent;

import org.qtproject.qt.android.bindings.QtActivity;

// Qt's own QtActivity never overrides onNewIntent(), so when Android
// delivers a new Intent to this already-running Activity (it uses
// android:launchMode="singleTop" — see AndroidManifest.xml) — e.g. the
// OAuth redirect GoogleSignInHelper.checkForPendingRedirect() polls for —
// Activity.getIntent() keeps returning the ORIGINAL launch intent forever
// instead of the new one. Overriding it here to call setIntent() is what
// makes that redirect visible to native code at all.
public class PassepartoutActivity extends QtActivity
{
    @Override
    public void onNewIntent(Intent intent)
    {
        super.onNewIntent(intent);
        setIntent(intent);
    }
}
