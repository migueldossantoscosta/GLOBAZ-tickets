trigger BilheteTrigger on Bilhete__c (after insert, after update, after undelete, before delete) {
    new BilheteTriggerHandler().run();
}