package com.cozydating.server.util;

import java.util.Collections;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public class GeoDistanceUtil {

    public static class Coordinates {
        public final double latitude;
        public final double longitude;

        public Coordinates(double latitude, double longitude) {
            this.latitude = latitude;
            this.longitude = longitude;
        }
    }

    private static final Map<String, Coordinates> COMMUNE_COORDINATES;

    static {
        Map<String, Coordinates> map = new HashMap<>();

        // Región Metropolitana - Gran Santiago
        map.put("santiago", new Coordinates(-33.4489, -70.6693));
        map.put("santiago centro", new Coordinates(-33.4489, -70.6693));
        map.put("providencia", new Coordinates(-33.4314, -70.6093));
        map.put("las condes", new Coordinates(-33.4116, -70.5672));
        map.put("ñuñoa", new Coordinates(-33.4569, -70.5975));
        map.put("nunoa", new Coordinates(-33.4569, -70.5975));
        map.put("vitacura", new Coordinates(-33.3820, -70.5606));
        map.put("lo barnechea", new Coordinates(-33.3556, -70.5186));
        map.put("la reina", new Coordinates(-33.4428, -70.5369));
        map.put("macul", new Coordinates(-33.4867, -70.6019));
        map.put("peñalolen", new Coordinates(-33.4839, -70.5489));
        map.put("penalolen", new Coordinates(-33.4839, -70.5489));
        map.put("la florida", new Coordinates(-33.5227, -70.5986));
        map.put("puente alto", new Coordinates(-33.6117, -70.5758));
        map.put("san miguel", new Coordinates(-33.4917, -70.6517));
        map.put("san joaquin", new Coordinates(-33.4939, -70.6278));
        map.put("maipu", new Coordinates(-33.5111, -70.7583));
        map.put("estacion central", new Coordinates(-33.4589, -70.6978));
        map.put("quinta normal", new Coordinates(-33.4339, -70.6961));
        map.put("recoleta", new Coordinates(-33.4078, -70.6389));
        map.put("independencia", new Coordinates(-33.4172, -70.6631));
        map.put("conchali", new Coordinates(-33.3833, -70.6667));
        map.put("huechuraba", new Coordinates(-33.3742, -70.6361));
        map.put("quilicura", new Coordinates(-33.3619, -70.7297));
        map.put("pudahuel", new Coordinates(-33.4422, -70.7583));
        map.put("cerrillos", new Coordinates(-33.5000, -70.7167));
        map.put("la cisterna", new Coordinates(-33.5278, -70.6639));
        map.put("san bernardo", new Coordinates(-33.5928, -70.7042));

        // Regiones Principales
        map.put("valparaiso", new Coordinates(-33.0472, -71.6127));
        map.put("viña del mar", new Coordinates(-33.0244, -71.5519));
        map.put("vina del mar", new Coordinates(-33.0244, -71.5519));
        map.put("concepcion", new Coordinates(-36.8270, -73.0503));
        map.put("la serena", new Coordinates(-29.9027, -71.2519));
        map.put("coquimbo", new Coordinates(-29.9533, -71.3436));
        map.put("antofagasta", new Coordinates(-23.6500, -70.4000));
        map.put("temuco", new Coordinates(-38.7359, -72.5904));
        map.put("valdivia", new Coordinates(-39.8142, -73.2459));
        map.put("puerto montt", new Coordinates(-41.4693, -72.9424));
        map.put("rancagua", new Coordinates(-34.1708, -70.7444));
        map.put("talca", new Coordinates(-35.4264, -71.6554));
        map.put("chillan", new Coordinates(-36.6066, -72.1034));
        map.put("arica", new Coordinates(-18.4783, -70.3126));
        map.put("iquique", new Coordinates(-20.2208, -70.1431));

        COMMUNE_COORDINATES = Collections.unmodifiableMap(map);
    }

    public static Coordinates getCoordinatesForCommune(String commune) {
        if (commune == null || commune.trim().isEmpty()) {
            return new Coordinates(-33.4489, -70.6693); // Default to Santiago Centro
        }
        String normalized = commune.trim().toLowerCase(Locale.ROOT);
        Coordinates coords = COMMUNE_COORDINATES.get(normalized);
        if (coords != null) {
            return coords;
        }
        // Partial matching
        for (Map.Entry<String, Coordinates> entry : COMMUNE_COORDINATES.entrySet()) {
            if (normalized.contains(entry.getKey()) || entry.getKey().contains(normalized)) {
                return entry.getValue();
            }
        }
        return new Coordinates(-33.4489, -70.6693); // Fallback
    }

    /**
     * Calculates geodesic distance between two points in Kilometers using Haversine formula.
     */
    public static double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Earth radius in km
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);

        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    public static double calculateDistanceKm(String communeA, String communeB) {
        Coordinates a = getCoordinatesForCommune(communeA);
        Coordinates b = getCoordinatesForCommune(communeB);
        return calculateDistanceKm(a.latitude, a.longitude, b.latitude, b.longitude);
    }
}
