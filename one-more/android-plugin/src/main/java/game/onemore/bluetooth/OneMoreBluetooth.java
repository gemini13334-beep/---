package game.onemore.bluetooth;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.provider.Settings;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.Closeable;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public final class OneMoreBluetooth extends GodotPlugin {
    private static final UUID SERVICE_ID = UUID.fromString("212c37b1-bdb6-4cf7-82cd-6d457dcc2521");
    private static final int PERMISSION_REQUEST = 7831;
    private static final int MAX_FRAME_BYTES = 32768;

    private final Object lock = new Object();
    private final ExecutorService workers = Executors.newCachedThreadPool();
    private final ArrayBlockingQueue<String> incoming = new ArrayBlockingQueue<>(24);
    private ArrayBlockingQueue<byte[]> outgoing = new ArrayBlockingQueue<>(24);
    private volatile String state = "idle";
    private volatile long generation;
    private BluetoothServerSocket listener;
    private BluetoothSocket socket;

    public OneMoreBluetooth(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "OneMoreBluetooth";
    }

    private BluetoothAdapter adapter() {
        Activity activity = getActivity();
        if (activity == null) {
            return null;
        }
        BluetoothManager manager = activity.getSystemService(BluetoothManager.class);
        return manager == null ? null : manager.getAdapter();
    }

    private boolean hasPermission() {
        Activity activity = getActivity();
        return activity != null
                && activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                == PackageManager.PERMISSION_GRANTED;
    }

    @UsedByGodot
    public String status() {
        BluetoothAdapter adapter = adapter();
        if (adapter == null) {
            return "unsupported";
        }
        if (!hasPermission()) {
            return "permission";
        }
        return adapter.isEnabled() ? state : "disabled";
    }

    @UsedByGodot
    public void requestAccess() {
        Activity activity = getActivity();
        if (activity != null && !hasPermission()) {
            activity.runOnUiThread(() -> activity.requestPermissions(
                    new String[] { Manifest.permission.BLUETOOTH_CONNECT }, PERMISSION_REQUEST));
        }
    }

    @UsedByGodot
    public void openSettings() {
        Activity activity = getActivity();
        if (activity != null) {
            activity.runOnUiThread(() -> activity.startActivity(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS)));
        }
    }

    @UsedByGodot
    public String pairedDevices() {
        JSONArray devices = new JSONArray();
        BluetoothAdapter adapter = adapter();
        if (adapter == null || !hasPermission()) {
            return devices.toString();
        }
        try {
            for (BluetoothDevice device : adapter.getBondedDevices()) {
                JSONObject entry = new JSONObject();
                String name = device.getName();
                entry.put("name", name == null || name.isBlank() ? "Устройство Bluetooth" : name);
                entry.put("address", device.getAddress());
                devices.put(entry);
            }
        } catch (SecurityException | JSONException ignored) {
            return "[]";
        }
        return devices.toString();
    }

    @UsedByGodot
    public boolean host() {
        BluetoothAdapter adapter = adapter();
        if (adapter == null || !hasPermission() || !adapter.isEnabled()) {
            return false;
        }
        synchronized (lock) {
            if (workers.isShutdown()) {
                return false;
            }
            closeSession("listening");
            long attempt = generation;
            workers.execute(() -> accept(adapter, attempt));
            return true;
        }
    }

    @UsedByGodot
    public boolean connectTo(String address) {
        BluetoothAdapter adapter = adapter();
        if (adapter == null || !hasPermission() || !adapter.isEnabled()
                || !BluetoothAdapter.checkBluetoothAddress(address)) {
            return false;
        }
        BluetoothDevice device;
        try {
            device = adapter.getRemoteDevice(address);
            if (device.getBondState() != BluetoothDevice.BOND_BONDED) {
                return false;
            }
        } catch (SecurityException failure) {
            return false;
        }
        synchronized (lock) {
            if (workers.isShutdown()) {
                return false;
            }
            closeSession("connecting");
            long attempt = generation;
            workers.execute(() -> connect(device, attempt));
            return true;
        }
    }

    private void accept(BluetoothAdapter adapter, long attempt) {
        try (BluetoothServerSocket server = adapter.listenUsingRfcommWithServiceRecord("ONE MORE", SERVICE_ID)) {
            synchronized (lock) {
                if (attempt != generation) {
                    return;
                }
                listener = server;
            }
            BluetoothSocket accepted = server.accept(60000);
            try {
                if (accepted.getRemoteDevice().getBondState() == BluetoothDevice.BOND_BONDED) {
                    startSession(accepted, attempt);
                    return;
                }
            } finally {
                closeQuietly(accepted);
            }
            fail(attempt);
        } catch (IOException | SecurityException failure) {
            fail(attempt);
        }
    }

    private void connect(BluetoothDevice device, long attempt) {
        try {
            BluetoothSocket client = device.createRfcommSocketToServiceRecord(SERVICE_ID);
            synchronized (lock) {
                if (attempt != generation) {
                    closeQuietly(client);
                    return;
                }
                socket = client;
            }
            client.connect();
            startSession(client, attempt);
        } catch (IOException | SecurityException failure) {
            fail(attempt);
        }
    }

    private void startSession(BluetoothSocket connection, long attempt) {
        synchronized (lock) {
            if (attempt != generation) {
                closeQuietly(connection);
                return;
            }
            socket = connection;
            closeQuietly(listener);
            listener = null;
            state = "connected";
            ArrayBlockingQueue<byte[]> frames = outgoing;
            workers.execute(() -> writeFrames(connection, attempt, frames));
        }
        readFrames(connection, attempt);
    }

    private void readFrames(BluetoothSocket connection, long attempt) {
        try {
            DataInputStream input = new DataInputStream(connection.getInputStream());
            while (attempt == generation) {
                int length = input.readInt();
                if (length <= 0 || length > MAX_FRAME_BYTES) {
                    throw new IOException("Invalid frame length");
                }
                byte[] frame = new byte[length];
                input.readFully(frame);
                synchronized (lock) {
                    if (attempt == generation && !incoming.offer(new String(frame, StandardCharsets.UTF_8))) {
                        throw new IOException("Receive queue is full");
                    }
                }
            }
        } catch (IOException failure) {
            fail(attempt);
        }
    }

    private void writeFrames(BluetoothSocket connection, long attempt, ArrayBlockingQueue<byte[]> frames) {
        try {
            DataOutputStream output = new DataOutputStream(connection.getOutputStream());
            while (attempt == generation) {
                byte[] frame = frames.poll(250, TimeUnit.MILLISECONDS);
                if (frame != null && attempt == generation) {
                    output.writeInt(frame.length);
                    output.write(frame);
                    output.flush();
                }
            }
        } catch (IOException failure) {
            fail(attempt);
        } catch (InterruptedException failure) {
            Thread.currentThread().interrupt();
        }
    }

    @UsedByGodot
    public boolean send(String message) {
        byte[] frame = message.getBytes(StandardCharsets.UTF_8);
        synchronized (lock) {
            return state.equals("connected") && frame.length > 0 && frame.length <= MAX_FRAME_BYTES
                    && outgoing.offer(frame);
        }
    }

    @UsedByGodot
    public String poll() {
        String message = incoming.poll();
        return message == null ? "" : message;
    }

    @UsedByGodot
    public void stop() {
        synchronized (lock) {
            closeSession("idle");
        }
    }

    @Override
    public void onMainDestroy() {
        synchronized (lock) {
            closeSession("idle");
            workers.shutdownNow();
        }
    }

    private void fail(long attempt) {
        synchronized (lock) {
            if (attempt == generation) {
                closeSession(state.equals("connected") ? "disconnected" : "connection_failed");
            }
        }
    }

    private void closeSession(String nextState) {
        generation++;
        closeQuietly(listener);
        closeQuietly(socket);
        listener = null;
        socket = null;
        incoming.clear();
        outgoing = new ArrayBlockingQueue<>(24);
        state = nextState;
    }

    private static void closeQuietly(Closeable connection) {
        if (connection != null) {
            try {
                connection.close();
            } catch (IOException ignored) {
                // The session is already being closed.
            }
        }
    }
}
