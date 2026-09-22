package com.cozydating.server.model;

public class User {
    private String id;
    private String username;
    private String email;
    private String passwordHash;
    private int age;
    private String commune;
    private int ticketsBalance;
    private String avatarConfig; // JSON string
    private String tastes;       // JSON string
    private String profilePhoto;  // Base64 or URL string
    private String photos;        // JSON array string of up to 6 photos
    private boolean isVerified;   // Identity verified via selfie comparison
    private String verificationSelfie; // URL to private verification selfie
    private String roomConfig;    // JSON string
    private String gender = "OTHER"; // MAN, WOMAN, NON_BINARY, OTHER
    private String seekingGender = "ANY"; // MAN, WOMAN, ANY
    private boolean isInternational = false;
    private Double latitude;
    private Double longitude;
    private double maxDistanceKm = 25.0;
    private String createdAt;
    private String updatedAt;

    public User() {
    }

    public User(String id, String username, String email, String passwordHash, int age, String commune,
                int ticketsBalance, String avatarConfig, String tastes, String roomConfig) {
        this(id, username, email, passwordHash, age, commune, ticketsBalance, avatarConfig, tastes, null, roomConfig);
    }

    public User(String id, String username, String email, String passwordHash, int age, String commune,
                int ticketsBalance, String avatarConfig, String tastes, String profilePhoto, String roomConfig) {
        this.id = id;
        this.username = username;
        this.email = email;
        this.passwordHash = passwordHash;
        this.age = age;
        this.commune = commune;
        this.ticketsBalance = ticketsBalance;
        this.avatarConfig = avatarConfig;
        this.tastes = tastes;
        this.profilePhoto = profilePhoto;
        this.roomConfig = roomConfig;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public int getAge() {
        return age;
    }

    public void setAge(int age) {
        this.age = age;
    }

    public String getCommune() {
        return commune;
    }

    public void setCommune(String commune) {
        this.commune = commune;
    }

    public int getTicketsBalance() {
        return ticketsBalance;
    }

    public void setTicketsBalance(int ticketsBalance) {
        this.ticketsBalance = ticketsBalance;
    }

    public String getAvatarConfig() {
        return avatarConfig;
    }

    public void setAvatarConfig(String avatarConfig) {
        this.avatarConfig = avatarConfig;
    }

    public String getTastes() {
        return tastes;
    }

    public void setTastes(String tastes) {
        this.tastes = tastes;
    }

    public String getProfilePhoto() {
        return profilePhoto;
    }

    public void setProfilePhoto(String profilePhoto) {
        this.profilePhoto = profilePhoto;
    }

    public String getPhotos() {
        return photos;
    }

    public void setPhotos(String photos) {
        this.photos = photos;
    }

    public boolean isVerified() {
        return isVerified;
    }

    public void setVerified(boolean verified) {
        isVerified = verified;
    }

    public String getVerificationSelfie() {
        return verificationSelfie;
    }

    public void setVerificationSelfie(String verificationSelfie) {
        this.verificationSelfie = verificationSelfie;
    }

    public String getRoomConfig() {
        return roomConfig;
    }

    public void setRoomConfig(String roomConfig) {
        this.roomConfig = roomConfig;
    }

    public String getGender() {
        return gender != null ? gender : "OTHER";
    }

    public void setGender(String gender) {
        this.gender = gender;
    }

    public String getSeekingGender() {
        return seekingGender != null ? seekingGender : "ANY";
    }

    public void setSeekingGender(String seekingGender) {
        this.seekingGender = seekingGender;
    }

    public boolean isInternational() {
        return isInternational;
    }

    public void setInternational(boolean international) {
        isInternational = international;
    }

    public Double getLatitude() {
        return latitude;
    }

    public void setLatitude(Double latitude) {
        this.latitude = latitude;
    }

    public Double getLongitude() {
        return longitude;
    }

    public void setLongitude(Double longitude) {
        this.longitude = longitude;
    }

    public double getMaxDistanceKm() {
        return maxDistanceKm;
    }

    public void setMaxDistanceKm(double maxDistanceKm) {
        this.maxDistanceKm = maxDistanceKm;
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
