#include <stdio.h>
#include <stdlib.h>

/* A linked list node */
typedef struct node {
  int value;
  struct node *next;
} node_t;

int main(void) {
  // Initializing a linked list
  node_t *head = malloc(sizeof(node_t));

  if (head == NULL) {
    exit(1);
  }

  head->value = 1;
  head->next = malloc(sizeof(node_t));

  if (head->next == NULL) {
    exit(1);
  }

  head->next->value = 2;
  head->next->next = NULL;

  // Iterating over a list
  node_t *current = head;

  while (current != NULL) {
    printf("%d\n", current->value);
    current = current->next;
  }

  return 0;
}
