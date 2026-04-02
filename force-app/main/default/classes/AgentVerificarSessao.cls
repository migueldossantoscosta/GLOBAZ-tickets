public with sharing class AgentVerificarSessao {

    public class Input {
        @InvocableVariable(label='Account ID (do cookie globaz_uid)' required=false)
        public String accountId;
    }

    public class Output {
        @InvocableVariable(label='Está autenticado?')
        public Boolean isLoggedIn;

        @InvocableVariable(label='Primeiro nome')
        public String firstName;

        @InvocableVariable(label='Nome completo')
        public String fullName;

        @InvocableVariable(label='Email')
        public String email;

        @InvocableVariable(label='Cidade (do perfil)')
        public String cidade;

        @InvocableVariable(label='Categorias preferidas')
        public String categoriasPreferidas;

        @InvocableVariable(label='Mensagem de erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Verificar Sessão do Utilizador'
        description = 'Verifica se o accountId corresponde a um utilizador válido e retorna o seu perfil.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> verificarSessao(List<Input> inputs) {
        Output out = new Output();
        out.isLoggedIn = false;

        try {
            Input inp = inputs[0];

            if (String.isBlank(inp.accountId)) {
                out.erroMsg = 'Sem sessão ativa.';
                return new List<Output>{ out };
            }

            Id accId;
            try {
                accId = (Id) inp.accountId;
            } catch (Exception e) {
                out.erroMsg = 'ID de sessão inválido.';
                return new List<Output>{ out };
            }

            List<Account> accs = [
                SELECT Id, FirstName, LastName, PersonEmail,
                       BillingCity, CategoriaFavorita__c
                FROM   Account
                WHERE  Id             = :accId
                AND    IsPersonAccount = true
                AND    Valido__c       = true
                LIMIT  1
            ];

            if (accs.isEmpty()) {
                out.erroMsg = 'Conta não encontrada ou inválida.';
                return new List<Output>{ out };
            }

            Account acc          = accs[0];
            out.isLoggedIn       = true;
            out.firstName        = acc.FirstName;
            out.fullName         = (acc.FirstName + ' ' + acc.LastName).trim();
            out.email            = acc.PersonEmail;
            out.cidade           = acc.BillingCity;
            out.categoriasPreferidas = acc.CategoriaFavorita__c;

        } catch (Exception e) {
            out.isLoggedIn = false;
            out.erroMsg    = 'Erro: ' + e.getMessage();
        }

        return new List<Output>{ out };
    }
}