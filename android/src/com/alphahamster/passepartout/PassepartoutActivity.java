package com.alphahamster.passepartout;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import org.qtproject.qt.android.bindings.QtActivity;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

// Qt's own QtActivity never overrides onNewIntent(), so when Android
// delivers a new Intent to this already-running Activity (it uses
// android:launchMode="singleTask" — see AndroidManifest.xml) —
// Activity.getIntent() keeps returning the ORIGINAL launch intent forever
// instead of the new one. Overriding it here to call setIntent() is what
// makes that new intent visible to native code at all (via getIntent()).
//
// nativeOnNewIntent() additionally pushes a live notification down into
// C++ (see AppLifecycleBridge) — Qt.application.state was tried first as a
// way for QML to notice "a new intent might be waiting", but doesn't
// reliably transition on every warm resume, silently missing some. This
// call is unconditional and can't be missed.
public class PassepartoutActivity extends QtActivity
{
    // Set once this process's Qt native application has finished starting
    // (see onCreate() below). Mirrors QtNative's own package-private
    // isStarted flag, which we can't read directly from here, but resets
    // to false the same way theirs does: only by the whole process dying.
    private static boolean sQtStarted = false;

    private static final String RESCUE_FILE_NAME = "pending_share_rescue.ppset";

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        // Android sometimes delivers a new ACTION_VIEW intent (e.g. tapping
        // a shared file in Telegram) to this singleTask Activity via a fresh
        // onCreate() instead of onNewIntent() on the already-running
        // instance — which race causes this is outside our control. When
        // that happens while this process already has a running Qt
        // application, QtActivityBase.onCreate() (invoked below via
        // super.onCreate()) detects it via QtNative's isStarted flag and
        // calls its own restartApplication(): fires a bare ACTION_MAIN
        // intent at itself, then Runtime.getRuntime().exit(0)s — silently
        // discarding this Intent's data (the shared file) with no way for
        // us to intervene once that call chain starts. Rescue the file to
        // local disk here, before that happens, so the next (real) cold
        // start below can recover it via adoptRescuedShare().
        if (sQtStarted)
            rescuePendingShare();

        super.onCreate(savedInstanceState);

        // Only reached if the block above didn't just get us restarted —
        // i.e. this really is (or already was) a running Qt application.
        sQtStarted = true;
        adoptRescuedShare();
    }

    @Override
    public void onNewIntent(Intent intent)
    {
        super.onNewIntent(intent);
        setIntent(intent);
        // Never let a problem here (e.g. the native method not having been
        // registered yet, for whatever reason) disrupt the rest of this
        // Activity's lifecycle — setIntent() above already made the new
        // Intent visible via getIntent() regardless of whether this call
        // itself succeeds.
        try {
            nativeOnNewIntent();
        } catch (Throwable t) {
            android.util.Log.w("Passepartout", "nativeOnNewIntent failed", t);
        }
    }

    // Copies the current Intent's shared file (if any) into our cache dir
    // under a fixed name, so it survives the process death that follows.
    // Best-effort: if there's nothing to rescue, or the copy fails (e.g. the
    // sending app's content provider is already gone), we just let the
    // restart proceed as it would have anyway.
    private void rescuePendingShare()
    {
        Intent intent = getIntent();
        if (intent == null || !Intent.ACTION_VIEW.equals(intent.getAction()))
            return;
        Uri uri = intent.getData();
        if (uri == null)
            return;

        File dest = new File(getCacheDir(), RESCUE_FILE_NAME);
        try (InputStream in = getContentResolver().openInputStream(uri);
             OutputStream out = new FileOutputStream(dest)) {
            if (in == null) {
                dest.delete();
                return;
            }
            byte[] buffer = new byte[8192];
            int read;
            while ((read = in.read(buffer)) != -1)
                out.write(buffer, 0, read);
        } catch (Exception e) {
            android.util.Log.w("Passepartout", "Failed to rescue pending share before forced restart", e);
            dest.delete();
        }
    }

    // If a previous Activity instance in this same restart cycle rescued a
    // shared file (see rescuePendingShare()), claim it and rewrite this
    // launch's Intent to point at the local copy — ShareHelper::
    // checkIncomingFile() already knows how to handle a plain file:// VIEW
    // intent, so no further native-side changes are needed. Renaming (not
    // just reading) the rescue file means it can never be adopted twice.
    private void adoptRescuedShare()
    {
        File rescued = new File(getCacheDir(), RESCUE_FILE_NAME);
        if (!rescued.exists())
            return;

        File claimed = new File(getCacheDir(), "rescued_" + System.currentTimeMillis() + ".ppset");
        if (!rescued.renameTo(claimed))
            return;

        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setData(Uri.fromFile(claimed));
        setIntent(intent);
    }

    private static native void nativeOnNewIntent();
}
