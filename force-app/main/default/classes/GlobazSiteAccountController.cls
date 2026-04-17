public without sharing class GlobazSiteAccountController {

    public Account account { get; private set; }
    public Boolean isLoggedIn { get; private set; }
    public List<Bilhete__c> bilhetesComprados { get; private set; }
    
    // Propriedades para bypass de FLS (Field Level Security) no site Guest
    public String accFirstName {get;set;}
    public String accLastName {get;set;}
    public String accEmail {get;set;}
    public String accPhone {get;set;}
    public String accNif {get;set;}
    public String accIban {get;set;}
    public String accFav {get;set;}
    public String accBorn {get;set;}
    public String accAge {get;set;}
    public Boolean accMark {get;set;}
    public Boolean accRgpd {get;set;}
    public Decimal accTotal {get;set;}
    public String accTotalStr {get;set;}
    public String accLast {get;set;}

    public List<String> categoriesList {get; private set;}

    public GlobazSiteAccountController() {
        categoriesList = new List<String>{'Cinema','Comédia / Stand-up','Concertos','Conferências','Cultura','Desporto','Eventos académicos','Eventos corporativos','Eventos solidários','Exposições','Feiras','Festas / nightlife','Festivais','Gaming / eSports','Gastronomia','Moda','Música eletrónica / DJs','Teatro','Tecnologia','Workshops'};
        isLoggedIn = false;
        bilhetesComprados = new List<Bilhete__c>();

        String accountId = ApexPages.currentPage().getParameters().get('uid');
        
        // Se não houver UID na URL, tenta buscar no cookie
        if (String.isBlank(accountId)) {
            Cookie uidCookie = ApexPages.currentPage().getCookies().get('globaz_uid');
            if (uidCookie != null) {
                accountId = uidCookie.getValue();
            }
        }

        if (String.isBlank(accountId) || !isSalesforceId(accountId)) {
            return;
        }

        try {
            List<Account> accs = [
                SELECT Id, FirstName, LastName, PersonEmail, Phone, CreatedDate, IsPersonAccount,
                       DataNascimento__c, CategoriaFavorita__c, Marketing__c, RGPD__c,
                       IBAN__c, Valido__c, Password__c, Idade__c, ValorTotalGasto__c,
                       DataUltimaCompra__c, NIF__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            if (!accs.isEmpty()) {
                account = accs[0];
                isLoggedIn = true;
                
                // Mapeia para variáveis locais para evitar problemas de FLS no VF
                accFirstName = account.FirstName;
                accLastName  = account.LastName;
                accEmail     = account.PersonEmail;
                accPhone     = account.Phone;
                accNif       = account.NIF__c;
                accIban      = account.IBAN__c;
                accFav       = account.CategoriaFavorita__c;
                accMark      = account.Marketing__c == true;
                accRgpd      = account.RGPD__c != null;
                Integer age = 0;
                if(account.DataNascimento__c != null) {
                    age = Date.today().year() - account.DataNascimento__c.year();
                    if(Date.today().dayOfYear() < account.DataNascimento__c.dayOfYear()) age--;
                    accBorn = account.DataNascimento__c.year() + '-' + 
                              String.valueOf(account.DataNascimento__c.month()).leftPad(2, '0') + '-' + 
                              String.valueOf(account.DataNascimento__c.day()).leftPad(2, '0');
                }
                accAge = (age > 0) ? String.valueOf(age) : '-';

                bilhetesComprados = [
                    SELECT Id, Name, Evento__r.Name, Fila__c, NumeroLugar__c, EstadoBilhete__c, CreatedDate
                    FROM Bilhete__c
                    WHERE Account__c = :accountId
                    ORDER BY CreatedDate DESC
                ];

                // CÁLCULO DE ESTATÍSTICAS VIA HELPER (Contexto de Sistema Garantido)
                GlobazStatsHelper.Stats st = GlobazStatsHelper.getAccountStats(accountId);
                accTotal = st.total;
                accTotalStr = st.totalStr;
                accLast = st.lastDate;
            }
        } catch (Exception e) {
            isLoggedIn = false;
        }
    }

    public Boolean getIsLoggedIn() {
        return isLoggedIn;
    }

    @RemoteAction
    public static String guardarConta(Map<String, String> dados) {
        try {
            Id accountId = (Id)dados.get('Id');
            Account acc = new Account(Id = accountId);

            System.debug('>>> Atualizando perfil: ' + acc.Id + ' - Dados: ' + dados);

            if(dados.containsKey('FirstName')) acc.FirstName = dados.get('FirstName');
            if(dados.containsKey('LastName')) acc.LastName = dados.get('LastName');
            if(dados.containsKey('PersonEmail')) acc.PersonEmail = dados.get('PersonEmail');
            if(dados.containsKey('Phone')) acc.Phone = dados.get('Phone');
            if(dados.containsKey('IBAN__c')) acc.IBAN__c = dados.get('IBAN__c');
            if(dados.containsKey('NIF__c')) acc.NIF__c = dados.get('NIF__c');
            
            // Password: Só atualiza se o utilizador escreveu algo (campo está vazio no UI por defeito)
            if(dados.containsKey('Password__c') && String.isNotBlank(dados.get('Password__c'))) {
                acc.Password__c = generatePasswordHash(dados.get('Password__c'));
                System.debug('>>> Password alterada com sucesso.');
            }
            
            if(dados.containsKey('CategoriaFavorita__c')) acc.CategoriaFavorita__c = dados.get('CategoriaFavorita__c');

            if(dados.containsKey('DataNascimento__c') && String.isNotBlank(dados.get('DataNascimento__c'))) {
                try {
                    acc.DataNascimento__c = Date.valueOf(dados.get('DataNascimento__c'));
                } catch(Exception e) {
                    System.debug('>>> Erro no formato da data: ' + dados.get('DataNascimento__c'));
                }
            } else if (dados.containsKey('DataNascimento__c')) {
                acc.DataNascimento__c = null;
            }

            if(dados.containsKey('Marketing__c')) acc.Marketing__c = Boolean.valueOf(dados.get('Marketing__c'));
            if(dados.containsKey('RGPD__c')) {
                if(dados.get('RGPD__c') == 'true') {
                    // Só atualiza a data se for a primeira vez ou se não tiver data
                    List<Account> current = [SELECT RGPD__c FROM Account WHERE Id = :accountId LIMIT 1];
                    if(!current.isEmpty() && current[0].RGPD__c == null) {
                        acc.RGPD__c = Datetime.now();
                    }
                } else {
                    acc.RGPD__c = null;
                }
            }

            update acc;
            System.debug('>>> Perfil atualizado com sucesso p/ ID: ' + acc.Id);
            return 'SUCESSO';
        } catch(DmlException e) {
            System.debug('>>> ERRO DML AO GUARDAR PERFIL: ' + e.getDmlMessage(0));
            return 'ERRO: ' + e.getDmlMessage(0);
        } catch(Exception e) {
            System.debug('>>> ERRO GERAL AO GUARDAR PERFIL: ' + e.getMessage());
            return 'ERRO: ' + e.getMessage();
        }
    }

    private static String generatePasswordHash(String pwd) {
        String toHash = pwd + 'GLOBAZ_TICKETS_2026_SECRET_KEY_XPTO';
        Blob hashBlob = Crypto.generateDigest('SHA256', Blob.valueOf(toHash));
        return EncodingUtil.convertToHex(hashBlob);
    }

    private static Boolean isSalesforceId(String idStr) {
        if (String.isBlank(idStr)) return false;
        Integer len = idStr.length();
        if (len != 15 && len != 18) return false;
        for (Integer i = 0; i < len; i++) {
            String c = idStr.substring(i, i+1);
            if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))) {
                return false;
            }
        }
        return true;
    }
}