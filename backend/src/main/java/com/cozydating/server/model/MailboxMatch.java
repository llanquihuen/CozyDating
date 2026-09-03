package com.cozydating.server.model;

public class MailboxMatch {
    private String id;
    private String userAId;
    private String userBId;
    private String userAName;
    private String userBName;
    private String userAAvatar;
    private String userBAvatar;
    private String userAPhoto;
    private String userBPhoto;
    private int userAAge;
    private int userBAge;
    private String userACommune;
    private String userBCommune;
    private String commonTastes;
    private String decisionA; // PENDING, KEEP_IN_TOUCH, ARCHIVED
    private String noteA;
    private String decisionB; // PENDING, KEEP_IN_TOUCH, ARCHIVED
    private String noteB;
    private boolean matched;
    private String createdAt;
    private String updatedAt;

    public MailboxMatch() {
    }

    public MailboxMatch(String id, String userAId, String userBId, String userAName, String userBName,
                        String userAAvatar, String userBAvatar, String userAPhoto, String userBPhoto,
                        int userAAge, int userBAge, String userACommune, String userBCommune,
                        String commonTastes, String decisionA, String noteA,
                        String decisionB, String noteB, boolean matched) {
        this.id = id;
        this.userAId = userAId;
        this.userBId = userBId;
        this.userAName = userAName;
        this.userBName = userBName;
        this.userAAvatar = userAAvatar;
        this.userBAvatar = userBAvatar;
        this.userAPhoto = userAPhoto;
        this.userBPhoto = userBPhoto;
        this.userAAge = userAAge;
        this.userBAge = userBAge;
        this.userACommune = userACommune;
        this.userBCommune = userBCommune;
        this.commonTastes = commonTastes;
        this.decisionA = decisionA;
        this.noteA = noteA;
        this.decisionB = decisionB;
        this.noteB = noteB;
        this.matched = matched;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getUserAId() {
        return userAId;
    }

    public void setUserAId(String userAId) {
        this.userAId = userAId;
    }

    public String getUserBId() {
        return userBId;
    }

    public void setUserBId(String userBId) {
        this.userBId = userBId;
    }

    public String getUserAName() {
        return userAName;
    }

    public void setUserAName(String userAName) {
        this.userAName = userAName;
    }

    public String getUserBName() {
        return userBName;
    }

    public void setUserBName(String userBName) {
        this.userBName = userBName;
    }

    public String getUserAAvatar() {
        return userAAvatar;
    }

    public void setUserAAvatar(String userAAvatar) {
        this.userAAvatar = userAAvatar;
    }

    public String getUserBAvatar() {
        return userBAvatar;
    }

    public void setUserBAvatar(String userBAvatar) {
        this.userBAvatar = userBAvatar;
    }

    public String getUserAPhoto() {
        return userAPhoto;
    }

    public void setUserAPhoto(String userAPhoto) {
        this.userAPhoto = userAPhoto;
    }

    public String getUserBPhoto() {
        return userBPhoto;
    }

    public void setUserBPhoto(String userBPhoto) {
        this.userBPhoto = userBPhoto;
    }

    public int getUserAAge() {
        return userAAge;
    }

    public void setUserAAge(int userAAge) {
        this.userAAge = userAAge;
    }

    public int getUserBAge() {
        return userBAge;
    }

    public void setUserBAge(int userBAge) {
        this.userBAge = userBAge;
    }

    public String getUserACommune() {
        return userACommune;
    }

    public void setUserACommune(String userACommune) {
        this.userACommune = userACommune;
    }

    public String getUserBCommune() {
        return userBCommune;
    }

    public void setUserBCommune(String userBCommune) {
        this.userBCommune = userBCommune;
    }

    public String getCommonTastes() {
        return commonTastes;
    }

    public void setCommonTastes(String commonTastes) {
        this.commonTastes = commonTastes;
    }

    public String getDecisionA() {
        return decisionA;
    }

    public void setDecisionA(String decisionA) {
        this.decisionA = decisionA;
    }

    public String getNoteA() {
        return noteA;
    }

    public void setNoteA(String noteA) {
        this.noteA = noteA;
    }

    public String getDecisionB() {
        return decisionB;
    }

    public void setDecisionB(String decisionB) {
        this.decisionB = decisionB;
    }

    public String getNoteB() {
        return noteB;
    }

    public void setNoteB(String noteB) {
        this.noteB = noteB;
    }

    public boolean isMatched() {
        return matched;
    }

    public void setMatched(boolean matched) {
        this.matched = matched;
    }

    public String getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }

    public String getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(String updatedAt) {
        this.updatedAt = updatedAt;
    }
}
