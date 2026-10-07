package com.cozydating.server.util;

import com.cozydating.server.model.User;

import java.util.Map;

/**
 * The partner fields a letter or a reveal needs to draw their two-sided profile card: the real
 * bio, the card style, the verified seal and their tastes (the featured ones must be among them).
 * Read live from the partner's user row, so later edits show up in old letters too.
 */
public final class PartnerCardFields {

    private PartnerCardFields() {
    }

    public static void putInto(Map<String, Object> target, User partner) {
        if (partner == null) {
            return;
        }
        if (partner.getBio() != null && !partner.getBio().trim().isEmpty()) {
            target.put("partnerBio", partner.getBio().trim());
        }
        if (partner.getCardStyle() != null && !partner.getCardStyle().isEmpty()) {
            target.put("partnerCardStyle", partner.getCardStyle());
        }
        if (partner.getTastes() != null && !partner.getTastes().isEmpty()) {
            target.put("partnerTastes", partner.getTastes());
        }
        target.put("partnerVerified", partner.isVerified());
    }
}
