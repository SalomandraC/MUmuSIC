package com.example.mumusic

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var speechResult: MethodChannel.Result? = null
    private val speechRequest = 4712
    private val CHANNEL = "com.example.mumusic/nfc"
    private var nfcTag: Tag? = null

    // Удаление файлов через MediaStore (файлы в общей папке «Загрузки»,
    // которые приложение не может удалить напрямую из-за scoped storage)
    private val FILES_CHANNEL = "com.example.mumusic/files"
    private val DELETE_REQUEST_CODE = 4711
    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingDeletePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mumusic/speech").setMethodCallHandler { call, result ->
            if (call.method != "listen") {
                result.notImplemented()
            } else if (speechResult != null) {
                result.error("busy", "Распознавание уже запущено", null)
            } else {
                val intent = Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    .putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE_MODEL, android.speech.RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    .putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                    .putExtra(android.speech.RecognizerIntent.EXTRA_PROMPT, "Play me track …")
                speechResult = result
                try {
                    startActivityForResult(intent, speechRequest)
                } catch (e: android.content.ActivityNotFoundException) {
                    speechResult = null
                    result.error("unavailable", "Установите службу распознавания речи Android", null)
                }
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNfcIntent" -> {
                    if (nfcTag != null) {
                        result.success(true)
                        nfcTag = null
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "deleteFile" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("ARG", "path is null", null)
                    } else {
                        deleteFile(path, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun findMediaUri(path: String): Uri? {
        val collection = MediaStore.Files.getContentUri("external")
        @Suppress("DEPRECATION")
        val dataColumn = MediaStore.MediaColumns.DATA
        contentResolver.query(
            collection,
            arrayOf(MediaStore.MediaColumns._ID),
            "$dataColumn = ?",
            arrayOf(path),
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return ContentUris.withAppendedId(collection, cursor.getLong(0))
            }
        }
        return null
    }

    private fun deleteFile(path: String, result: MethodChannel.Result) {
        val file = File(path)
        if (!file.exists()) {
            result.success(true)
            return
        }
        try {
            if (file.delete()) {
                result.success(true)
                return
            }
        } catch (_: Exception) {
        }

        val uri = findMediaUri(path)
        if (uri == null) {
            result.success(!file.exists())
            return
        }
        try {
            contentResolver.delete(uri, null, null)
            result.success(!file.exists())
        } catch (e: SecurityException) {
            // Файл создан другой установкой приложения: просим пользователя подтвердить
            val intentSender = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
                    MediaStore.createDeleteRequest(contentResolver, listOf(uri)).intentSender
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && e is RecoverableSecurityException ->
                    e.userAction.actionIntent.intentSender
                else -> null
            }
            if (intentSender == null) {
                result.error("DENIED", e.message, null)
                return
            }
            pendingDeleteResult?.success(false)
            pendingDeleteResult = result
            pendingDeletePath = path
            try {
                startIntentSenderForResult(intentSender, DELETE_REQUEST_CODE, null, 0, 0, 0)
            } catch (ex: Exception) {
                pendingDeleteResult = null
                pendingDeletePath = null
                result.error("DENIED", ex.message, null)
            }
        } catch (e: Exception) {
            result.error("DELETE_FAILED", e.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == speechRequest) {
            val phrase = data?.getStringArrayListExtra(android.speech.RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
            speechResult?.success(if (resultCode == Activity.RESULT_OK) phrase else null)
            speechResult = null
            return
        }
        if (requestCode != DELETE_REQUEST_CODE) return
        val result = pendingDeleteResult ?: return
        val path = pendingDeletePath
        pendingDeleteResult = null
        pendingDeletePath = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(false)
            return
        }
        if (path != null && File(path).exists() && Build.VERSION.SDK_INT == Build.VERSION_CODES.Q) {
            // На Android 10 после подтверждения удаляем повторно
            try {
                findMediaUri(path)?.let { contentResolver.delete(it, null, null) }
            } catch (_: Exception) {
            }
        }
        result.success(path == null || !File(path).exists())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleNfcIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNfcIntent(intent)
    }

    private fun handleNfcIntent(intent: Intent?) {
        if (intent == null) return
        
        when (intent.action) {
            NfcAdapter.ACTION_NDEF_DISCOVERED,
            NfcAdapter.ACTION_TAG_DISCOVERED,
            NfcAdapter.ACTION_TECH_DISCOVERED -> {
                // Перехватываем NFC событие, чтобы системное приложение не открылось
                @Suppress("DEPRECATION")
                nfcTag = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
                } else {
                    intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
                }
            }
        }
    }
}
