package ovh.look.game;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.*;
import java.util.logging.Logger;
import java.util.stream.Collectors;

import io.netty.channel.EventLoop;

public class GameServerManager {
    private static final Logger Log = Logger.getLogger(GameServerManager.class.getName());
    private static final int GAME_SERVER_STOP_TIMEOUT = 10;
    private static final int GAME_SERVER_START_TIMEOUT = 1;
    private static final int MAX_ROOMS = 10;
    private static EventLoop eventLoop = null;
    private static boolean gameStopNeeded = false;
    private static Runnable gameServerStopCallbackFn = null;
    private static Queue<Integer> gameServerStartPidQueue = new LinkedBlockingQueue<>();
    private static Map<Integer, Process> gameServerPidToProcess = new ConcurrentHashMap<>();
    private static Map<Integer, GameServerConnector> gameServerPidToConnector = new ConcurrentHashMap<>();
    private final Set<Integer> runningPorts = new HashSet<>();

    private static final boolean isLinux = System.getProperty("os.name").toLowerCase().contains("linux");
    private static final boolean isMac = System.getProperty("os.name").toLowerCase().contains("mac");
    private static final boolean isWin = System.getProperty("os.name").toLowerCase().contains("win");


    private static class GameServerManagerHolder {
        private static final GameServerManager INSTANCE = new GameServerManager();
    }

    private GameServerManager() {
    }

    public static GameServerManager getInstance() {
        return GameServerManagerHolder.INSTANCE;
    }
   
    public static void setEventLoop(EventLoop loop) {
        eventLoop = loop;
    }

    public static int getGspid() throws InterruptedException {
        return gameServerStartPidQueue.poll();
    }

    public List<ProcessHandle> findGameProcess() {
        List<ProcessHandle> processes = ProcessHandle.allProcesses()
                .filter(ph -> ph.info().command().map(cmd -> cmd.contains("dmengine_headless")).orElse(false))
                .collect(Collectors.toList());
        Log.info("Found " + processes.size() + " GS processes");
        return processes;
    }

    public CompletableFuture<Void> terminateProcessByPid(int pid) {
        Process process = gameServerPidToProcess.get(pid);
        if (process != null) {
            Log.info("[PID:" + process.pid() + "] - Process found. Terminating it.");
            process.destroy();
            return process.onExit().thenRun(() -> gameServerPidToProcess.remove(pid));
        } else {
            Log.info("[PID:" + pid + "] - Process NOT found");
            return CompletableFuture.completedFuture(null);
        }
    }

    public void terminateProcess(ProcessHandle process) {
        Log.info(process + "[PID:" + process.pid() + "] - Process found. Terminating it.");
        process.destroy();
        try {
            process.onExit().get();
        } catch (InterruptedException | ExecutionException e) {
            Log.severe("Failed to terminate process: " + e.getMessage());
            process.destroyForcibly();
            // Thread.currentThread().interrupt();
        }
    }

    public void terminateGameServer(Integer pid) {
        Log.info("terminate_game_server " + pid);
        List<ProcessHandle> processList = findGameProcess();
        if (pid == null) {
            Log.info("Found " + processList.size() + " game servers to terminate.");
            for (ProcessHandle process : processList) {
                terminateProcess(process);
            }
        } else {
            for (ProcessHandle process : processList) {
                Log.info(process.toString());
                if (process.pid() == (pid + 1) && gameServerPidToProcess.get(pid) != null) {
                    terminateProcess(process);
                    gameServerPidToProcess.remove(pid);
                    var connector = gameServerPidToConnector.remove(pid);
                    runningPorts.remove(connector.getPort());
                }
            }
        }
    }
    public void stopGameServer(int pid, Runnable fn) {
        gameServerStopCallbackFn = fn;
        gameStopNeeded = true;
        Log.info("stop " + gameStopNeeded);
        terminateGameServer(pid);
    }

    public void startGameServer() {
        gameStopNeeded = false;
        List<ProcessHandle> processList = findGameProcess();
        int size = processList.size();

        if (size < MAX_ROOMS) {
            startGameServerProcess();
        } else {
            Log.info("MAX " + size + " Game Server Processes like " + processList.get(0).info().command().orElse("") + " already running.");
        }
    }

    private void startGameServerProcess() {
        Log.info("Game Server starting...");
        try {
            Process process = new ProcessBuilder(System.getenv("START_GAME_SERVER_SHELL_SCRIPT")).start();
            int pid = (int) process.pid();
            if (!gameServerPidToProcess.containsKey(pid)) {
                gameServerPidToProcess.put(pid, process);
                gameServerStartPidQueue.add(pid);

                var connector = new GameServerConnector("127.0.0.1", getAvailablePort(), pid);
                gameServerPidToConnector.put(pid, connector);
                connector.connect();
                runningPorts.add(connector.getPort());
                
                Log.info("Game Server[PID:" + pid + "], running: " + gameServerPidToProcess.size() + ", in queue: " + gameServerStartPidQueue.size());
            }
        } catch (IOException e) {
            Log.severe("Failed to start game server: " + e.getMessage());
        }
    }

    private int getAvailablePort() {
        int port = 5002;
        while (runningPorts.contains(port)) {
            port++;
        }
        return port;
    }
}