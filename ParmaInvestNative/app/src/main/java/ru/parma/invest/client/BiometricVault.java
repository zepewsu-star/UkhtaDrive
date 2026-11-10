package ru.parma.invest.client;

import android.content.Context;
import android.content.SharedPreferences;
import android.hardware.biometrics.BiometricManager;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Защита пароля с помощью системного Android Keystore и отпечатка. */
final class BiometricVault {
    private static final String ALIAS="parma_invest_biometric_v1";
    private static final String PREFS="parma_invest_biometric_v1";
    private BiometricVault(){}

    static boolean isSupported(Context c) {
        if(Build.VERSION.SDK_INT<Build.VERSION_CODES.R)return false;
        try {
            BiometricManager mgr=c.getSystemService(BiometricManager.class);
            return mgr!=null && mgr.canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_STRONG)
                ==BiometricManager.BIOMETRIC_SUCCESS;
        } catch(Exception e) {return false;}
    }
    private static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
    }
    static boolean isEnabled(Context c) {
        return prefs(c).contains("iv") && prefs(c).contains("encrypted");
    }
    private static SecretKey key(boolean create) throws Exception {
        KeyStore ks=KeyStore.getInstance("AndroidKeyStore");
        ks.load(null);
        SecretKey existing=(SecretKey)ks.getKey(ALIAS,null);
        if(existing!=null || !create)return existing;
        KeyGenerator generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
        KeyGenParameterSpec spec=new KeyGenParameterSpec.Builder(ALIAS,
            KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationParameters(0,KeyProperties.AUTH_BIOMETRIC_STRONG)
            .setInvalidatedByBiometricEnrollment(true)
            .build();
        generator.init(spec);
        return generator.generateKey();
    }
    static Cipher newEncryptCipher(Context c) throws Exception {
        if(!isSupported(c))throw new IllegalStateException("Отпечаток недоступен");
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE,key(true));
        return cipher;
    }
    static Cipher newDecryptCipher(Context c) throws Exception {
        String rawIv=prefs(c).getString("iv",null);
        if(rawIv==null)throw new IllegalStateException("Отпечаток не настроен");
        SecretKey secret=key(false);
        if(secret==null)throw new IllegalStateException("Нет ключа");
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE,secret,
            new GCMParameterSpec(128,Base64.decode(rawIv,Base64.DEFAULT)));
        return cipher;
    }
    static void storeEncrypted(Context c,Cipher authorized,String password) throws Exception {
        byte[] encrypted=authorized.doFinal(password.getBytes(StandardCharsets.UTF_8));
        byte[] iv=authorized.getIV();
        if(iv==null||iv.length!=12)throw new IllegalStateException("Нет IV");
        if(!prefs(c).edit().putString("iv",Base64.encodeToString(iv,Base64.NO_WRAP))
                .putString("encrypted",Base64.encodeToString(encrypted,Base64.NO_WRAP))
                .commit())throw new IllegalStateException("Не удалось сохранить");
    }
    static String decrypt(Context c,Cipher authorized) throws Exception {
        String value=prefs(c).getString("encrypted",null);
        if(value==null)throw new IllegalStateException("Нет сохранённого пароля");
        byte[] decrypted=authorized.doFinal(Base64.decode(value,Base64.DEFAULT));
        return new String(decrypted,StandardCharsets.UTF_8);
    }
    static void forget(Context c) {
        prefs(c).edit().clear().commit();
        try {
            KeyStore ks=KeyStore.getInstance("AndroidKeyStore");
            ks.load(null);
            if(ks.containsAlias(ALIAS))ks.deleteEntry(ALIAS);
        } catch(Exception ignored) {
            // Записи удалены даже если системный ключ уже недоступен.
        }
    }
}
