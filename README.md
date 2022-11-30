# sysadmin-carlosfeu
Práctica sysadmin Carlos Feu Fernández

-El primer paso, es clonar el repositorio de GitHub: https://github.com/carlosfeufernandez/sysadmin-carlosfeu.git

-El segundo paso, a través de la terminal entramos en sysadmin-carlosfeu/WP-ELK-VM. Una vez dentro lanzamos el comando vagrant up para levantar las 2 máquinas.

 En el código de la provisión de discos de ambas máquinas, se encuentra comentado el comando "shutdown -r now" para en caso de querer realizarlo veremos que aparece el disco ya que se ha metido la entrada en el fstab.

-El tercer paso, es acceder a través del navegador http://localhost:8080/ para ver wordpress y a la dirección http://localhost:8081/ para kibana a través del siguiente "User: kibanaadmin Psw: patodegoma"

-El último paso es acceder a la carpeta "CapturaKibana" para visualizar las capturas de su correcto funcionamiento.
