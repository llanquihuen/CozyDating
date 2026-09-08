package com.cozydating.server.model;

public class ChatMessage {
    private String id;
    private String matchId;
    private String senderId;
    private String receiverId;
    private String text;
    private String dateType;
    private String createdAt;

    public ChatMessage() {
    }

    public ChatMessage(String id, String matchId, String senderId, String receiverId, String text, String dateType, String createdAt) {
        this.id = id;
        this.matchId = matchId;
        this.senderId = senderId;
        this.receiverId = receiverId;
        this.text = text;
        this.dateType = dateType;
        this.createdAt = createdAt;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getMatchId() {
        return matchId;
    }

    public void setMatchId(String matchId) {
        this.matchId = matchId;
    }

    public String getSenderId() {
        return senderId;
    }

    public void setSenderId(String senderId) {
        this.senderId = senderId;
    }

    public String getReceiverId() {
        return receiverId;
    }

    public void setReceiverId(String receiverId) {
        this.receiverId = receiverId;
    }

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    public String getDateType() {
        return dateType;
    }

    public void setDateType(String dateType) {
        this.dateType = dateType;
    }

    public String getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }
}
