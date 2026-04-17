Id accId = '001fj00000pOcy2AAC';
List<Order> orders = [SELECT TotalAmount, EffectiveDate FROM Order WHERE AccountId = :accId AND Status = 'Activated'];
Decimal total = 0;
Date lastD = null;
for(Order o : orders) {
    total += (o.TotalAmount != null ? o.TotalAmount : 0);
    if(o.EffectiveDate != null && (lastD == null || o.EffectiveDate > lastD)) lastD = o.EffectiveDate;
}
update new Account(
    Id = accId,
    ValorTotalGasto__c = total,
    DataUltimaCompra__c = lastD
);
System.debug('>>> Stats da conta do Ricardo Almeida atualizadas: ' + total + ' EUR, Ultima: ' + lastD);
