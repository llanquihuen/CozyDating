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
    
    private final String userAId;
    private final String userBId;
    private String userAName;
    private String userBName;
    private Object userAAvatar;
    private Object userBAvatar;
    private Object userARoom;
    private Object userBRoom;
    private Object userATastes;
    private Object userBTastes;

    private String explorerName;
    private Object explorerAvatar;
    private Object explorerRoom;
    private Object explorerTastes;
    private String guideName;
    private Object guideAvatar;
    private Object guideRoom;
    private Object guideTastes;
    private boolean mailboxRecorded = false;
    
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
        this.userAId = explorerId;
        this.userBId = guideId;
        this.mode = mode;
        this.livekitTokenExplorer = livekitTokenExplorer;
        this.livekitTokenGuide = livekitTokenGuide;
        this.dungeonSeed = dungeonSeed;
        this.act = 1;
    }

    public void setParticipantData(String explorerName, Object explorerAvatar, Object explorerRoom, Object explorerTastes,
                                   String guideName, Object guideAvatar, Object guideRoom, Object guideTastes) {
        this.explorerName = explorerName;
        this.explorerAvatar = explorerAvatar;
        this.explorerRoom = explorerRoom;
        this.explorerTastes = explorerTastes;
        this.guideName = guideName;
        this.guideAvatar = guideAvatar;
        this.guideRoom = guideRoom;
        this.guideTastes = guideTastes;

        // Immutable session identity (User A is initial explorer, User B is initial guide)
        this.userAName = explorerName;
        this.userAAvatar = explorerAvatar;
        this.userARoom = explorerRoom;
        this.userATastes = explorerTastes;
        this.userBName = guideName;
        this.userBAvatar = guideAvatar;
        this.userBRoom = guideRoom;
        this.userBTastes = guideTastes;
    }

    public String getUserAId() { return userAId; }
    public String getUserBId() { return userBId; }
    public String getUserAName() { return userAName; }
    public String getUserBName() { return userBName; }
    public Object getUserAAvatar() { return userAAvatar; }
    public Object getUserBAvatar() { return userBAvatar; }
    public Object getUserARoom() { return userARoom; }
    public Object getUserBRoom() { return userBRoom; }
    public Object getUserATastes() { return userATastes; }
    public Object getUserBTastes() { return userBTastes; }

    public String getExplorerName() { return explorerName; }
    public Object getExplorerAvatar() { return explorerAvatar; }
    public Object getExplorerRoom() { return explorerRoom; }
    public Object getExplorerTastes() { return explorerTastes; }
    public String getGuideName() { return guideName; }
    public Object getGuideAvatar() { return guideAvatar; }
    public Object getGuideRoom() { return guideRoom; }
    public Object getGuideTastes() { return guideTastes; }
    public boolean isMailboxRecorded() { return mailboxRecorded; }
    public void setMailboxRecorded(boolean mailboxRecorded) { this.mailboxRecorded = mailboxRecorded; }


    public void swapRoles(long newSeed) {
        String tempId = this.explorerId;
        this.explorerId = this.guideId;
        this.guideId = tempId;

        WebSocketSession tempSession = this.explorerSession;
        this.explorerSession = this.guideSession;
        this.guideSession = tempSession;

        String tempName = this.explorerName;
        this.explorerName = this.guideName;
        this.guideName = tempName;

        Object tempAvatar = this.explorerAvatar;
        this.explorerAvatar = this.guideAvatar;
        this.guideAvatar = tempAvatar;

        Object tempRoom = this.explorerRoom;
        this.explorerRoom = this.guideRoom;
        this.guideRoom = tempRoom;

        Object tempTastes = this.explorerTastes;
        this.explorerTastes = this.guideTastes;
        this.guideTastes = tempTastes;

        this.act = 2;
        this.dungeonSeed = newSeed;
        this.explorerReady = false;
        this.guideReady = false;
    }

    public void setAct(int act) {
        this.act = act;
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
