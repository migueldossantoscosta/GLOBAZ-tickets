Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
email.setToAddresses(new String[] { 'miguelcostinha521@gmail.com' });
email.setSubject('Teste Direto do Globaz Tickets');
email.setPlainTextBody('Olá Miguel! Se receberes este email, o sistema de envio de emails do Salesforce está a funcionar. O problema é exclusivo da classe do Bilhete.');
List<Messaging.SendEmailResult> results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
for (Messaging.SendEmailResult res : results) {
    if (res.isSuccess()) {
        System.debug('SUCESSO TOTAL NO ENVIO');
    } else {
        System.debug('FALHA: ' + res.getErrors()[0].getMessage());
    }
}
