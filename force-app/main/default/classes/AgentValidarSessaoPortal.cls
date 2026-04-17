public with sharing class AgentValidarSessaoPortal {

    public class Input {
        @InvocableVariable(label='ID da Conta Portal')
        public String idContaPortal;
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

        @InvocableVariable(label='Cidade')
        public String cidade;

        @InvocableVariable(label='Categorias preferidas')
        public String categoriasPreferidas;

        @InvocableVariable(label='Mensagem de erro')
        public String erroMsg;

        @InvocableVariable(label='ID da Conta Portal Output')
        public String idContaPortalOut;
    }

    @InvocableMethod(
        label='Agente - Validar Sessao Portal'
        description='Verifica se o ID da conta corresponde a um utilizador válido no portal Globaz.'
        category='GLOBAZ Tickets'
    )
    public static List<Output> validarSessao(List<Input> inputs) {
        Output out = new Output();
        out.isLoggedIn = false;

        try {
            if (inputs == null || inputs.isEmpty()) {
                out.erroMsg = 'Sem dados de entrada.';
                return new List<Output>{ out };
            }

            Input inp = inputs[0];

            if (String.isBlank(inp.idContaPortal)) {
                out.erroMsg = 'Sem sessao ativa.';
                return new List<Output>{ out };
            }

            Id accId;
            try {
                accId = (Id) inp.idContaPortal;
            } catch (Exception e) {
                out.erroMsg = 'ID de sessao invalido.';
                return new List<Output>{ out };
            }

            List<Account> accs = [
                SELECT Id, FirstName, LastName, PersonEmail, BillingCity, CategoriaFavorita__c
                FROM Account
                WHERE Id = :accId
                AND IsPersonAccount = true
                AND Valido__c = true
                LIMIT 1
            ];

            if (accs.isEmpty()) {
                out.erroMsg = 'Conta nao encontrada ou invalida.';
                return new List<Output>{ out };
            }

            Account acc = accs[0];
            out.isLoggedIn = true;
            out.firstName = acc.FirstName;
            out.fullName = ((acc.FirstName == null ? '' : acc.FirstName) + ' ' + (acc.LastName == null ? '' : acc.LastName)).trim();
            out.email = acc.PersonEmail;
            out.cidade = acc.BillingCity;
            out.categoriasPreferidas = (String)acc.get('CategoriaFavorita__c');
            out.idContaPortalOut = String.valueOf(acc.Id);

        } catch (Exception e) {
            out.isLoggedIn = false;
            out.erroMsg = 'Erro: ' + e.getMessage();
        }

        return new List<Output>{ out };
    }
}
