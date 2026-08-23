package com.cozydating.server.model;

import org.springframework.web.socket.WebSocketSession;

import java.util.concurrent.ScheduledFuture;

public class GameRoom {
    private final String roomId;
    private String explorerId;
    private String guideId;
    
    private WebSocketSession explorerSession;
    private WebSocketSession guideSession;
    
    private final String mode;
    private final String livekitTokenExplorer;
    private final String livekitTokenGuide;
    
    private long dungeonSeed;
    private int act = 1;
    
    private boolean paused = false;
    private boolean explorerReady = false;
    private boolean guideReady = false;
    
    private ScheduledFuture<?> reconnectGraceTask;
    private String disconnectedUserId;

    public GameRoom(String roomId, String explorerId, WebSocketSession explorerSession,
                    String guideId, WebSocketSession guideSession, String mode,
                    String livekitTokenExplorer, String livekitTokenGuide,
                    long dungeonSeed) {
        this.roomId = roomId;
        this.explorerId = explorerId;
        this.explorerSession = explorerSession;
        this.guideId = guideId;
        this.guideSession = guideSession;
        this.mode = mode;
        this.livekitTokenExplorer = livekitTokenExplorer;
        this.livekitTokenGuide = livekitTokenGuide;
        this.dungeonSeed = dungeonSeed;
        this.act = 1;
    }

    public void swapRoles(long newSeed) {
        String tempId = this.explorerId;
        this.explorerId = this.guideId;
        this.guideId = tempId;

        WebSocketSession tempSession = this.explorerSession;
        this.explorerSession = this.guideSession;
        this.guideSession = tempSession;

        this.act = 2;
        this.dungeonSeed = newSeed;
        this.explorerReady = false;
        this.guideReady = false;
    }

    public long getDungeonSeed() {
        return dungeonSeed;
    }

    public int getAct() {
        return act;
    }

    public String getRoomId() {
        return roomId;
    }

    public String getExplorerId() {
        return explorerId;
    }

    public String getGuideId() {
        return guideId;
    }

    public WebSocketSession getExplorerSession() {
        return explorerSession;
    }

    public void setExplorerSession(WebSocketSession explorerSession) {
        this.explorerSession = explorerSession;
    }

    public WebSocketSession getGuideSession() {
        return guideSession;
    }

    public void setGuideSession(WebSocketSession guideSession) {
        this.guideSession = guideSession;
    }

    public String getMode() {
        return mode;
    }

    public String getLivekitTokenExplorer() {
        return livekitTokenExplorer;
    }

    public String getLivekitTokenGuide() {
        return livekitTokenGuide;
    }

    public boolean isPaused() {
        return paused;
    }

    public void setPaused(boolean paused) {
        this.paused = paused;
    }

    public boolean isExplorerReady() {
        return explorerReady;
    }

    public void setExplorerReady(boolean explorerReady) {
        this.explorerReady = explorerReady;
    }

    public boolean isGuideReady() {
        return guideReady;
    }

    public void setGuideReady(boolean guideReady) {
        this.guideReady = guideReady;
    }

    /**
     * Checks if both players have confirmed the start of the game.
     */
    public boolean isBothReady() {
        return explorerReady && guideReady;
    }

    public ScheduledFuture<?> getReconnectGraceTask() {
        return reconnectGraceTask;
    }

    public void setReconnectGraceTask(ScheduledFuture<?> reconnectGraceTask) {
        this.reconnectGraceTask = reconnectGraceTask;
    }

    public String getDisconnectedUserId() {
        return disconnectedUserId;
    }

    public void setDisconnectedUserId(String disconnectedUserId) {
        this.disconnectedUserId = disconnectedUserId;
    }

    public String getPartnerId(String userId) {
        if (userId.equals(explorerId)) {
            return guideId;
        } else if (userId.equals(guideId)) {
            return explorerId;
        }
        return null;
    }

    public WebSocketSession getPartnerSession(String userId) {
        if (userId.equals(explorerId)) {
            return guideSession;
        } else if (userId.equals(guideId)) {
            return explorerSession;
        }
        return null;
    }
}
