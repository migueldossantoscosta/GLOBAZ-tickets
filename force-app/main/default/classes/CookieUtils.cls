public with sharing class CookieUtils {
    
    /**
     * Sets a cookie with the specified name, value, and expiration days
     * @param name The name of the cookie
     * @param value The value of the cookie
     * @param days Number of days until expiration (optional)
     */
    public static void setCookie(String name, String value, Integer days) {
        PageReference pageRef = ApexPages.currentPage();
        // Set cookie with secure and sameSite attributes
        pageRef.setCookie(name, value, days, true, 'Strict');
    }
    
    /**
     * Gets the value of a cookie by name
     * @param name The name of the cookie to retrieve
     * @return The value of the cookie or null if not found
     */
    public static String getCookie(String name) {
        PageReference pageRef = ApexPages.currentPage();
        return pageRef.getCookie(name);
    }
    
    /**
     * Deletes a cookie by setting its expiration to a past date
     * @param name The name of the cookie to delete
     */
    public static void deleteCookie(String name) {
        PageReference pageRef = ApexPages.currentPage();
        pageRef.setCookie(name, '', -1);
    }
}