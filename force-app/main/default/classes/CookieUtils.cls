public with sharing class CookieUtils {
    
    /**
     * Sets a cookie with the specified name, value, and expiration days
     * @param name The name of the cookie
     * @param value The value of the cookie
     * @param days Number of days until expiration (optional)
     */
    public static void setCookie(String name, String value, Integer days) {
        // days to seconds. If null or -1, it's a session cookie
        Integer maxAge = (days != null && days > 0) ? days * 86400 : -1;
        Cookie c = new Cookie(name, value, '/', maxAge, true);
        if (ApexPages.currentPage() != null) {
            ApexPages.currentPage().setCookies(new Cookie[]{c});
        }
    }
    
    /**
     * Gets the value of a cookie by name
     * @param name The name of the cookie to retrieve
     * @return The value of the cookie or null if not found
     */
    public static String getCookie(String name) {
        if (ApexPages.currentPage() == null) return null;
        Cookie c = ApexPages.currentPage().getCookies().get(name);
        return c != null ? c.getValue() : null;
    }
    
    /**
     * Deletes a cookie by setting its expiration to a past date
     * @param name The name of the cookie to delete
     */
    public static void deleteCookie(String name) {
        setCookie(name, '', 0);
    }
}